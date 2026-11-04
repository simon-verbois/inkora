import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/offline/data/download_ahead_store.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/catalogue_fakes.dart';
import '../support/reader_fakes.dart';

class _Queries extends QueryInterceptor {
  int plans = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('WITH volumes AS')) plans++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late AppDatabase database;
  late DownloadAheadStore ahead;
  late CatalogueStore catalogue;
  late ProgressStore progress;
  late _Queries queries;
  Future<void> publish([String generation = 'one']) async {
    await catalogue.stage(generation, [
      entry('library-a', kind: CatalogueKind.library),
      entry('series-a', kind: CatalogueKind.series),
      for (var i = 1; i <= 6; i++) entry('b$i', number: i.toDouble()),
      const CatalogueItem(
        kind: CatalogueKind.book,
        id: 'epub',
        title: 'Zero-page EPUB',
        seriesId: 'series-a',
        libraryId: 'library-a',
        number: 7,
        metadata: CatalogueMetadata(mediaType: 'application/epub+zip'),
      ),
      entry('removed', number: 8, available: false),
    ]);
    await catalogue.publish(generation, DateTime.now(), () => true);
  }

  Future<void> observe(String book, {bool completed = false}) =>
      progress.observe(
        book,
        ProgressSnapshot(
          revision: 'revision-a',
          pageIndex: 1,
          completed: completed,
        ),
      );
  setUp(() async {
    queries = _Queries();
    database = AppDatabase(NativeDatabase.memory().interceptWith(queries));
    ahead = DownloadAheadStore(database, 'reader-account');
    catalogue = CatalogueStore(database, 'reader-account');
    progress = ProgressStore(database, 'reader-account');
    await publish();
  });
  tearDown(() async => database.close());

  test('opt-in is account-local, bounded, sequenced and anchored at the current volume', () async {
    expect(await ahead.watchTargets().first, isEmpty);
    await ahead.configure('series-a', 2);
    expect(await ahead.watchTargets().first, ['b1', 'b2']);
    await LibraryVisibilityStore(database, 'reader-account').save({});
    expect(await ahead.watchTargets().first, isEmpty);
    await LibraryVisibilityStore(database, 'reader-account').save(null);
    expect(
      await DownloadAheadStore(database, 'other').watchTargets().first,
      isEmpty,
    );
    await observe('b3');
    expect(await ahead.watchTargets().first, ['b3', 'b4']);
    await observe('b3', completed: true);
    // Finishing a later volume never backfills skipped earlier books.
    expect(await ahead.watchTargets().first, ['b4', 'b5']);
    for (final book in ['b1', 'b2', 'b4', 'b5']) {
      await observe(book, completed: true);
    }
    await ahead.configure('series-a', 3);
    expect(await ahead.watchTargets().first, ['b6', 'epub']);
    await ahead.configure('series-a', 0);
    expect(await ahead.watchTargets().first, isEmpty);
    expect(() => ahead.configure('series-a', 100), throwsArgumentError);
  });

  test('page writes do not requery plans; completion, rule and publication changes do', () async {
    await ahead.configure('series-a', 2);
    final values = <List<String>>[];
    final sub = ahead.watchTargets().listen(values.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await progress.save(
      readerManifest(book: 'b1', count: 10),
      ReaderLocator(1, 0),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final before = queries.plans;
    await progress.save(
      readerManifest(book: 'b1', count: 10),
      ReaderLocator(2, 0),
    );
    await progress.save(
      readerManifest(book: 'b1', count: 10),
      ReaderLocator(3, 0),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(queries.plans, before);
    await progress.save(
      readerManifest(book: 'b1', count: 10),
      ReaderLocator(9, 0),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(values.last, ['b2', 'b3']);
    await ahead.configure('series-a', 3);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(values.last, ['b2', 'b3', 'b4']);
    final published = queries.plans;
    await publish('two');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(queries.plans, greaterThan(published));
  });

  test('persisted rule survives database reopen', () async {
    final root = await Directory.systemTemp.createTemp('inkora-ahead-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/db');
    var db = AppDatabase(NativeDatabase(file));
    await DownloadAheadStore(db, 'a').configure('series', 3);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect(await DownloadAheadStore(db, 'a').count('series'), 3);
    expect(await DownloadAheadStore(db, 'b').count('series'), 0);
    await db.close();
  });

  test('revoked automatic admission never publishes a late manifest', () async {
    final root = await Directory.systemTemp.createTemp('inkora-ahead-admit-');
    final store = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/staging'),
    );
    final assets = ReaderAssetStore(
      database,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    final entered = Completer<void>(), release = Completer<void>();
    var allowed = true;
    final scheduler = DownloadScheduler(
      store,
      assets,
      PageNetworkGate(),
      loadManifest: (book, _) async {
        entered.complete();
        await release.future;
        return readerManifest(book: book);
      },
      transfer: (_, _, _, _, _) => throw StateError('Unexpected transfer'),
      isCurrent: () => true,
    );
    try {
      final work = scheduler.enqueue('b1', allow: () => allowed);
      final assertion = expectLater(work, throwsStateError);
      await entered.future;
      allowed = false;
      release.complete();
      await assertion;
      expect(await store.jobs(), isEmpty);
    } finally {
      scheduler.close();
      await assets.idle;
      await root.delete(recursive: true);
    }
  });
}
