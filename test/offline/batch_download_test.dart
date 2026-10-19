import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/presentation/batch_download_sheet.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/catalogue_fakes.dart';
import '../support/connection_fakes.dart';
import '../support/reader_fakes.dart';
import 'progress_sync_test.dart' show FakeRemote;

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late Directory root;
  late OfflineCoordinator service;
  late CatalogueRepository catalogue;
  late ProviderContainer container;
  final loads = <String>[];
  Completer<ReaderManifest>? held;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('inkora-batch-test-');
    final assets = ReaderAssetStore(
      db,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    final store = DownloadStore(
      db,
      'reader-account',
      Directory('${root.path}/stage'),
    );
    final gate = PageNetworkGate();
    loads.clear();
    held = null;
    service = OfflineCoordinator(
      store,
      assets,
      savedSession,
      DownloadScheduler(
        store,
        assets,
        gate,
        loadManifest: (book, _) async {
          loads.add(book);
          if (book == 'e') throw StateError('Fixture manifest failure');
          if (book == 'c' && held != null) return held!.future;
          return readerManifest(book: book);
        },
        transfer: (_, _, _, _, _) => throw StateError('No implicit transfers'),
        isCurrent: () => true,
      ),
      ProgressSync(
        ProgressStore(db, 'reader-account'),
        FakeRemote(),
        gate,
        isCurrent: () => true,
      ),
      BackgroundTransfer(),
      () => true,
    );
    await service.downloads.suspend(true);
    final books = CatalogueStore(
      db,
      'reader-account',
      applyLibraryVisibility: false,
    );
    await books.stage('g', [
      for (final id in ['a', 'b', 'c', 'd', 'e'])
        CatalogueItem(
          kind: CatalogueKind.book,
          id: id,
          title: 'Volume $id',
          seriesId: 'series',
          number: id.codeUnitAt(0).toDouble(),
        ),
    ]);
    await books.publish('g', DateTime.now(), () => true);
    catalogue = CatalogueRepository(books, FakeCatalogueRemote());
    await store.enqueue(readerManifest(book: 'a'));
    final b = await store.enqueue(readerManifest(book: 'b'));
    await db.customUpdate(
      "UPDATE download_jobs SET state='paused' WHERE id=?",
      variables: [Variable(b)],
      updates: {db.downloadJobs},
    );
    container = ProviderContainer(
      overrides: [
        catalogueRepositoryProvider.overrideWith((ref) async => catalogue),
        offlineCoordinatorProvider.overrideWith((ref) async => service),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    service.close();
    catalogue.close();
    await service.downloads.idle;
    await db.close();
    await root.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: BatchDownloadSheet(seriesId: 'series')),
        ),
      ),
    );
    await _frames(tester);
  }

  testWidgets(
    'next three skips queued books, resumes paused jobs and durably admits the rest',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Next 3 unread volumes'));
      await _frames(tester);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Volume b'),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Volume a'),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.text('Download selection (3)'));
      await _frames(tester);
      final jobs = await tester.runAsync(() => service.store.watch().first);
      expect(jobs!.map((j) => j.bookId).toSet(), {'a', 'b', 'c', 'd'});
      expect(jobs.every((j) => j.state == DownloadState.queued), isTrue);
      expect(loads, ['c', 'd']);
      expect(find.text('Queued: 3 · Failed: 0'), findsOneWidget);
      await tester.tap(find.text('Clear selection'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Volume e'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(BatchDownloadSheet),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.tap(find.text('Volume e'));
      await tester.pump();
      await tester.tap(find.text('Download selection (1)'));
      await _frames(tester);
      expect(find.text('Queued: 0 · Failed: 1'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Volume e'),
            )
            .value,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
  testWidgets(
    'stop admits the current request but preserves unsubmitted selections',
    (tester) async {
      held = Completer<ReaderManifest>();
      await mount(tester);
      await tester.tap(find.text('Next 3 unread volumes'));
      await _frames(tester);
      await tester.tap(find.text('Download selection (3)'));
      for (var i = 0; i < 12 && !loads.contains('c'); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(loads, ['c']);
      await tester.tap(find.text('Stop adding volumes'));
      held!.complete(readerManifest(book: 'c'));
      await _frames(tester);
      final jobs = await tester.runAsync(() => service.store.watch().first);
      expect(jobs!.map((j) => j.bookId).toSet(), {'a', 'b', 'c'});
      expect(find.text('Download selection (1)'), findsOneWidget);
      expect(loads, ['c']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
}
