import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/features/connection/application/session_controller.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  for (final count in [5, 6]) {
    testWidgets(
      'manga offset toggles twice before settings refresh, $count pages',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        final directory = Directory.systemTemp.createTempSync('inkora-offset-');
        final store = ReaderStore(database, 'reader-account');
        final manifest = readerManifest(count: count);
        await tester.runAsync(
          () => store.saveOverrides(
            SettingsScope.library,
            manifest.libraryId!,
            const ReadingOverrides(mode: ReadingMode.manga),
          ),
        );
        final client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          FixtureAdapter((_) => jsonResponse(userJson)),
        );
        final repository = ReaderRepository(
          store,
          ReaderAssetStore(
            database,
            Directory('${directory.path}/cache'),
            Directory('${directory.path}/downloads'),
          ),
          client,
          PageNetworkGate(),
          isCurrent: () => true,
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(Future.value(database)),
            catalogueRepositoryProvider.overrideWith((ref) async => null),
            coverRepositoryProvider.overrideWith((ref) async => null),
            downloadedBooksProvider.overrideWith((ref) => Stream.value([])),
            readerRepositoryProvider.overrideWith((ref) async => repository),
            openReaderProvider(manifest.bookId).overrideWith(
              (ref) async =>
                  OpenReader(manifest, FixturePageSource(), ReaderLocator(0)),
            ),
          ],
        );
        Future<void> settle() async {
          for (var i = 0; i < 5; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 25)),
            );
            await tester.pump();
          }
          await settleReaderImages(tester);
        }

        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(home: ReaderScreen(bookId: manifest.bookId)),
            ),
          );
          await settle();
          await tester.tapAt(const Offset(20, 300));
          await settle();
          final button = find.byKey(const Key('reader-spread-offset'));
          final viewport = tester.state(find.byType(ReaderViewport));
          expect(tester.widget<IconButton>(button).isSelected, true);
          expect(find.text('p. 1'), findsOneWidget);
          // Both presses reach the old rendered callback before the database
          // stream has had an event-loop turn to publish the first write.
          await tester.tap(button);
          await tester.tap(button);
          await settle();
          expect(tester.widget<IconButton>(button).isSelected, true);
          expect(find.text('p. 1'), findsOneWidget);
          expect(tester.state(find.byType(ReaderViewport)), same(viewport));
          await tester.tap(button);
          await settle();
          expect(tester.widget<IconButton>(button).isSelected, false);
          expect(find.text('p. 1–2'), findsOneWidget);
          expect(
            (await tester.runAsync(
              () => store.overrides(SettingsScope.book, manifest.bookId),
            ))!.spreadOffset,
            false,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await settle();
          repository.close();
          client.close();
          await tester.runAsync(database.close);
          await tester.runAsync(() => directory.delete(recursive: true));
        }
      },
    );
  }

  testWidgets(
    'opening failure is visible immediately and retry opens the reader',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final directory = Directory.systemTemp.createTempSync('inkora-screen-');
      final book =
          (jsonDecode(
                        File(
                          'test/fixtures/komga/1.28.1/catalogue/local-book-0.json',
                        ).readAsStringSync(),
                      )['content']
                      as List)
                  .first
              as Map<String, dynamic>;
      (book['media'] as Map)['mediaProfile'] = 'EPUB';
      final adapter = FixtureAdapter((_) => jsonResponse(book));
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final repository = ReaderRepository(
        ReaderStore(database, savedSession.accountId),
        ReaderAssetStore(
          database,
          Directory('${directory.path}/cache'),
          Directory('${directory.path}/downloads'),
        ),
        client,
        PageNetworkGate(),
        isCurrent: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          readerRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ReaderScreen(bookId: book['id'] as String)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        find.text('This book has no supported raster pages.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(adapter.requests.length, 1);
      final manifest = readerManifest(
        account: savedSession.accountId,
        book: book['id'] as String,
        count: 1,
      );
      await tester.runAsync(() => repository.store.saveManifest(manifest));
      // Retry uses a saved manifest without issuing a second metadata request.
      await tester.tap(find.text('Retry'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      await tester.tapAt(
        Offset(20, tester.getCenter(find.byType(ReaderScreen)).dy),
      );
      await settleReaderImages(tester);
      expect(find.text('p. 1'), findsOneWidget);
      expect(
        find.text('This book has no supported raster pages.'),
        findsNothing,
      );
      // The image request is deliberately invalid; it must remain a page-level error.
      expect(find.text('Retry page'), findsOneWidget);
      await tester.runAsync(database.close);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      repository.close();
      client.close();
      await tester.runAsync(() => directory.delete(recursive: true));
      expect(tester.takeException(), isNull);
    },
  );
}
