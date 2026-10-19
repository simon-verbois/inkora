import 'package:inkora/features/connection/application/session_controller.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';
import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';

Future<void> _asyncFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  await settleReaderImages(tester);
}

void main() {
  for (final available in [true, false]) {
    testWidgets(
      'finish sheet cancel preserves progress and handoff keeps origin ($available)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase(NativeDatabase.memory());
        final dir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('inkora-end-test-'),
        ))!;
        final store = CatalogueStore(
          db,
          'reader-account',
          applyLibraryVisibility: false,
        );
        await tester.runAsync(() async {
          await store.stage('g', [
            const CatalogueItem(
              kind: CatalogueKind.series,
              id: 'series',
              title: 'Fixture series',
            ),
            const CatalogueItem(
              kind: CatalogueKind.book,
              id: 'a',
              title: 'First volume',
              seriesId: 'series',
              number: 1,
            ),
            CatalogueItem(
              kind: CatalogueKind.book,
              id: 'b',
              title: 'Next volume',
              seriesId: 'series',
              number: 2,
              available: available,
            ),
          ]);
          await store.publish('g', DateTime.now(), () => true);
        });
        final catalogue = CatalogueRepository(store, FakeCatalogueRemote());
        final client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          FixtureAdapter((options) => jsonResponse(userJson)),
        );
        final repository = ReaderRepository(
          ReaderStore(db, 'reader-account'),
          ReaderAssetStore(
            db,
            Directory('${dir.path}/cache'),
            Directory('${dir.path}/downloads'),
          ),
          client,
          PageNetworkGate(),
          isCurrent: () => true,
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(Future.value(db)),
            readerRepositoryProvider.overrideWith((ref) async => repository),
            catalogueRepositoryProvider.overrideWith((ref) async => catalogue),
            coverRepositoryProvider.overrideWith((ref) async => null),
            downloadedBooksProvider.overrideWith((ref) => Stream.value([])),
            for (final id in ['a', 'b']) ...[
              openReaderProvider(id).overrideWith(
                (ref) async => OpenReader(
                  readerManifest(book: id),
                  FixturePageSource(),
                  ReaderLocator(0),
                ),
              ),
              readingSettingsProvider(id).overrideWith(
                (ref) => Stream.value(
                  const ReadingSettings(layout: ReadingLayout.single),
                ),
              ),
            ],
          ],
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      context.pushNamed('reader', pathParameters: {'id': 'a'}),
                  child: const Text('Open'),
                ),
              ),
            ),
            GoRoute(
              name: 'reader',
              path: '/reader/:id',
              builder: (_, state) =>
                  ReaderScreen(bookId: state.pathParameters['id']!),
            ),
            GoRoute(
              name: 'series-reader',
              path: '/series/:id/read/:bookId',
              builder: (_, state) =>
                  ReaderScreen(bookId: state.pathParameters['bookId']!),
            ),
            GoRoute(
              name: 'catalogue-detail',
              path: '/catalogue/:kind/:id',
              builder: (_, _) => const Scaffold(body: Text('Series details')),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.tap(find.text('Open'));
        await _asyncFrames(tester);
        await tester.tapAt(const Offset(195, 420));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish volume'));
        await _asyncFrames(tester);
        if (available) {
          expect(find.text('Next volume'), findsOneWidget);
          expect(
            find.text('Download required for offline reading'),
            findsOneWidget,
          );
        } else {
          expect(find.text('No next chapter is available.'), findsOneWidget);
        }
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(() => db.select(db.progressEvents).get()),
          isEmpty,
        );
        await tester.tap(find.text('Finish volume'));
        await _asyncFrames(tester);
        await tester.tap(
          find.text(available ? 'Read next volume' : 'Return to series'),
        );
        await _asyncFrames(tester);
        expect(
          router.routerDelegate.currentConfiguration.last.matchedLocation,
          available ? '/reader/b' : '/catalogue/series/series',
        );
        final events = await tester.runAsync(
          () => db.select(db.progressEvents).get(),
        );
        expect(
          events!.where((e) => e.bookId == 'a').single.operation,
          'complete',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 20));
        router.dispose();
        repository.close();
        catalogue.close();
        client.close();
        await tester.runAsync(db.close);
        await tester.runAsync(() => dir.delete(recursive: true));
      },
    );
  }
}
