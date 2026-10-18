import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/library/presentation/volume_list_tile.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'home, library/series/book details and ordered groups at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        await tester.runAsync(
          () =>
              UiPreferencesStore(database)
                  .save(const UiPreferences(setupCompleted: true)),
        );
        final remote = FakeCatalogueRemote();
        remote.items[CatalogueKind.library] = [
          entry('library-a', kind: CatalogueKind.library, title: 'My library'),
        ];
        remote.items[CatalogueKind.series] = [
          entry('series-a', kind: CatalogueKind.series, title: 'Series Alpha'),
          entry('series-b', kind: CatalogueKind.series, title: 'Series Bravo'),
        ];
        remote.items[CatalogueKind.book] = [
          entry('book-a', title: 'Book Alpha', number: 1),
          entry('book-b', title: 'Book Bravo', number: 2),
        ];
        remote.items[CatalogueKind.collection] = [
          entry(
            'collection',
            kind: CatalogueKind.collection,
            title: 'My collection',
            members: ['series-b', 'series-a'],
          ),
        ];
        remote.items[CatalogueKind.readlist] = [
          entry(
            'readlist',
            kind: CatalogueKind.readlist,
            title: 'My reading list',
            members: ['book-b', 'missing', 'book-a'],
          ),
        ];
        final repository = CatalogueRepository(
          CatalogueStore(database, savedSession.accountId),
          remote,
        );
        await tester.runAsync(repository.refresh);
        final adapter = FixtureAdapter(
          (_) => throw DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.connectionError,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            readerRepositoryProvider.overrideWith((ref) async => null),
            downloadsProvider.overrideWith((ref) => Stream.value([])),
            databaseProvider.overrideWithValue(Future.value(database)),
            sessionStoreProvider.overrideWithValue(
              MemorySessionStore()..saved = savedSession,
            ),
            komgaClientFactoryProvider.overrideWithValue(
              (endpoint, credentials) =>
                  fixtureClient(endpoint, credentials, adapter),
            ),
            catalogueRepositoryProvider.overrideWith((ref) async => repository),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await tester.pump();
          repository.close();
          await tester.runAsync(database.close);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const InkoraApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('library-selector')), findsOneWidget);
        expect(find.text('Continue reading'), findsNothing);
        await tester.tap(find.text('Libraries'));
        await tester.pumpAndSettle();
        container.read(routerProvider).go('/catalogue/library');
        await tester.pumpAndSettle();
        await tester.tap(find.text('My library'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browse all books'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Series Alpha'));
        await tester.pumpAndSettle();
        expect(find.text('Browse books'), findsNothing);
        await tester.scrollUntilVisible(
          find.descendant(
            of: find.byType(VolumeListTile),
            matching: find.text('Book Alpha'),
          ),
          250,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(VolumeListTile),
            matching: find.text('Book Alpha'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
          'book-a',
        );
        expect(find.text('Book details'), findsNothing);
        container.read(routerProvider).go('/catalogue/collection');
        await tester.pumpAndSettle();
        await tester.tap(find.text('My collection'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Browse all books'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Series Bravo')).dx,
          lessThan(tester.getTopLeft(find.text('Series Alpha')).dx),
        );
        container.read(routerProvider).go('/catalogue/readlist');
        await tester.pumpAndSettle();
        await tester.tap(find.text('My reading list'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Browse reading list'));
        await tester.tap(find.text('Browse reading list'));
        await tester.pumpAndSettle();
        final first = tester.getTopLeft(find.text('Book Bravo'));
        final second = tester.getTopLeft(
          find.descendant(
            of: find.byType(VolumeListTile),
            matching: find.text('Book Alpha'),
          ),
        );
        expect(
          first.dy < second.dy ||
              (first.dy == second.dy && first.dx < second.dx),
          isTrue,
        );
        expect(find.text('Unavailable or removed'), findsOneWidget);
        await tester.tap(find.text('Unavailable item'));
        await tester.pumpAndSettle();
        expect(find.text('Book Bravo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(database.close);
      },
    );
  }

  testWidgets(
    'offline search, sort and continuous scrolling survive failed refresh',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(
        () =>
            UiPreferencesStore(database)
                .save(const UiPreferences(setupCompleted: true)),
      );
      final remote = FakeCatalogueRemote();
      remote.items[CatalogueKind.book] = List.generate(
        35,
        (i) => entry('book-$i', title: 'Book ${i.toString().padLeft(2, '0')}'),
      );
      final repository = CatalogueRepository(
        CatalogueStore(database, savedSession.accountId),
        remote,
      );
      await tester.runAsync(repository.refresh);
      remote.failKind = CatalogueKind.library;
      final container = ProviderContainer(
        overrides: [
          readerRepositoryProvider.overrideWith((ref) async => null),
          downloadsProvider.overrideWith((ref) => Stream.value([])),
          databaseProvider.overrideWithValue(Future.value(database)),
          sessionStoreProvider.overrideWithValue(
            MemorySessionStore()..saved = savedSession,
          ),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) => fixtureClient(
              endpoint,
              credentials,
              FixtureAdapter((_) => jsonResponse(userJson)),
            ),
          ),
          catalogueRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await tester.pump();
        repository.close();
        await tester.runAsync(database.close);
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
      expect(find.byTooltip('Next page'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Book 30'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Book 30'), findsOneWidget);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 4000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue-search-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalogue-search')),
        'Book 03',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Book 03'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Title Z–A').last);
      await tester.pumpAndSettle();
      expect(find.text('Book 34'), findsOneWidget);
      final calls = remote.calls;
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, 400),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(remote.calls, greaterThan(calls));
      expect(
        find.textContaining('Saved catalogue remains available.'),
        findsOneWidget,
      );
      expect(find.text('Book 34'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(database.close);
    },
  );
}
