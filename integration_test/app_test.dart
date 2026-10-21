import 'dart:async';

import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../test/support/catalogue_fakes.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/data/secure_session_store.dart';

import '../test/support/connection_fakes.dart';

import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/core/storage/credential_store.dart';

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../test/support/reader_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native downloaded reader, preferences and webtoon locator survive database reopening',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = await Directory('${support.path}/reader-native-fixture')
          .create(recursive: true);
      final manifest = readerManifest(account: 'native-reader-fixture');
      var database = await openAppDatabase();
      final imported = await File('${directory.path}/import.png')
          .writeAsBytes(fixtureRaster);
      var assets = ReaderAssetStore(
        database,
        Directory('${directory.path}/cache'),
        Directory('${directory.path}/downloads'),
      );
      await assets.installVerifiedDownload(manifest, {
        for (var i = 0; i < manifest.pages.length; i++)
          i: DownloadAsset(
            imported,
            sha256.convert(fixtureRaster).toString(),
            'image/png',
            fixtureRaster.length,
          ),
      }, CancellationController());
      var store = ReaderStore(database, manifest.accountId);
      await store.saveLocator(manifest, ReaderLocator(1, .25));
      await store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        const ReadingOverrides(mode: ReadingMode.webtoon, spacing: 8),
      );
      await database.close();
      database = await openAppDatabase();
      store = ReaderStore(database, manifest.accountId);
      assets = ReaderAssetStore(
        database,
        Directory('${directory.path}/cache'),
        Directory('${directory.path}/downloads'),
      );
      final restored = (await store.manifest(manifest.bookId))!;
      final locator = await store.locator(restored);
      expect(locator.pageIndex, 1);
      expect(locator.fraction, .25);
      final remote = FixturePageSource()..offline = true;
      final source = TieredPageSource(
        restored,
        assets,
        remote,
        PageNetworkGate(),
      );
      final opened = OpenReader(restored, source, locator, offline: true);
      Future<void> mount(ReadingSettings settings) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              key: ValueKey(restored.key(0)),
              reader: opened,
              settings: settings,
              saveLocator: (position) => store.saveLocator(restored, position),
            ),
          ),
        ),
      );
      try {
        expect(
          (await source.read(
            restored.key(0),
            cancellation: CancellationController(),
          )).bytes,
          fixtureRaster,
        );
        await mount(await store.settings(restored).first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('webtoon-reader')), findsOneWidget);
        expect(find.text('p. 2'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('webtoon-reader')),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(
          (await store.locator(restored)).pageIndex,
          greaterThanOrEqualTo(1),
        );
        await store.saveOverrides(
          SettingsScope.book,
          manifest.bookId,
          const ReadingOverrides(
            mode: ReadingMode.paged,
            direction: ReadingDirection.rightToLeft,
          ),
        );
        await mount(await store.settings(restored).first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('paged-reader')), findsOneWidget);
        expect(remote.requests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        source.close();
        await assets.idle;
        final durablePosition = await store.locator(restored);
        await database.close();
        database = await openAppDatabase();
        store = ReaderStore(database, manifest.accountId);
        expect(
          (await store.locator(restored)).pageIndex,
          durablePosition.pageIndex,
        );
        expect(
          (await store.settings(restored).first).direction,
          ReadingDirection.rightToLeft,
        );
      } finally {
        source.close();
        await assets.idle;
        for (final table in [
          'progress_heads',
          'progress_events',
          'reader_manifests',
          'reader_assets',
          'reader_downloads',
          'reading_preferences',
          'reader_positions',
        ]) {
          await database.customStatement(
            'DELETE FROM $table WHERE account_id = ?',
            [manifest.accountId],
          );
        }
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('native login, offline restoration and guarded logout', (
    tester,
  ) async {
    final database = await openAppDatabase();
    final store = SecureSessionStore(Future.value(database), CredentialStore());
    await store.clear();
    addTearDown(() async {
      await store.clear();
      await database.close();
    });
    final adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.path.endsWith('users/me') ? userJson : {},
        status: options.path.endsWith('users/me') ? 200 : 404,
      ),
    );
    final first = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(Future.value(database)),
        sessionStoreProvider.overrideWithValue(store),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) =>
              fixtureClient(endpoint, credentials, adapter),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: first, child: const InkoraApp()),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Connect your Komga server to start reading.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('server-url')),
      'https://example.test/komga',
    );
    await tester.enterText(
      find.byKey(const Key('secret')),
      'non-secret-native-fixture',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selector')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    final offline = FixtureAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final second = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(Future.value(database)),
        sessionStoreProvider.overrideWithValue(
          SecureSessionStore(Future.value(database), CredentialStore()),
        ),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) =>
              fixtureClient(endpoint, credentials, offline),
        ),
      ],
    );
    addTearDown(second.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: second, child: const InkoraApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selector')), findsOneWidget);
    expect(find.textContaining('Offline · saved catalogue'), findsOneWidget);
    second.read(routerProvider).go('/settings/account');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Connect your Komga server to start reading.'),
      findsOneWidget,
    );
    expect(await store.restore(), isNull);
    second.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(
      find.text('Connect your Komga server to start reading.'),
      findsOneWidget,
    );
  });
  testWidgets('native credentials remain scoped to their account', (
    tester,
  ) async {
    final store = CredentialStore();
    const account = 'bootstrap-native-storage-test';
    addTearDown(() => store.delete(account));
    await store.write(account, 'non-secret-test-fixture');
    expect(await store.read(account), 'non-secret-test-fixture');
    expect(await store.read('$account-other'), isNull);
    await store.delete(account);
    expect(await store.read(account), isNull);
  });

  testWidgets('metadata survives closing and reopening the native database', (
    tester,
  ) async {
    const id = 'bootstrap-native-database-test';
    final first = await openAppDatabase();
    try {
      await first
          .into(first.serverProfiles)
          .insertOnConflictUpdate(
            ServerProfilesCompanion.insert(
              id: id,
              displayName: 'Native test fixture',
              baseUrl: 'https://example.test/',
            ),
          );
    } finally {
      await first.close();
    }
    final second = await openAppDatabase();
    try {
      final row = await (second.select(
        second.serverProfiles,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.displayName, 'Native test fixture');
    } finally {
      await (second.delete(
        second.serverProfiles,
      )..where((table) => table.id.equals(id))).go();
      await second.close();
    }
  });
  testWidgets(
    'native catalogue reopens and remains searchable after failed refresh',
    (tester) async {
      final first = await openAppDatabase();
      final remote = FakeCatalogueRemote();
      remote.items[CatalogueKind.book] = [
        entry('native-book', title: 'Offline native book'),
      ];
      final repository = CatalogueRepository(
        CatalogueStore(first, savedSession.accountId),
        remote,
      );
      await repository.refresh();
      repository.close();
      await first.close();
      final second = await openAppDatabase();
      final offline = FakeCatalogueRemote()..failKind = CatalogueKind.library;
      final reopened = CatalogueRepository(
        CatalogueStore(second, savedSession.accountId),
        offline,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(Future.value(second)),
          sessionStoreProvider.overrideWithValue(
            MemorySessionStore()..saved = savedSession,
          ),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) => fixtureClient(
              endpoint,
              credentials,
              FixtureAdapter(
                (options) => jsonResponse(
                  options.path.endsWith('users/me') ? userJson : {},
                  status: options.path.endsWith('users/me') ? 200 : 404,
                ),
              ),
            ),
          ),
          catalogueRepositoryProvider.overrideWith((ref) async => reopened),
        ],
      );
      addTearDown(() async {
        container.dispose();
        reopened.close();
        await second.transaction(() async {
          await (second.delete(
            second.catalogueEntries,
          )..where((row) => row.accountId.equals(savedSession.accountId))).go();
          await (second.delete(
            second.catalogueMemberships,
          )..where((row) => row.accountId.equals(savedSession.accountId))).go();
          await (second.delete(
            second.catalogueSnapshots,
          )..where((row) => row.accountId.equals(savedSession.accountId))).go();
        });
        await second.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const InkoraApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/catalogue/book');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalogue-search')),
        'native',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Offline native book'), findsOneWidget);
      // Pull to refresh (the refresh action has no toolbar button).
      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved catalogue remains available.'),
        findsOneWidget,
      );
      expect(find.text('Offline native book'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}
