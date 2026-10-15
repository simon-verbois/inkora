import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

String locator(double progression) =>
    '{"href":"chapter.xhtml","type":"application/xhtml+xml","locations":{"progression":$progression,"totalProgression":0.3}}';

class Remote implements ProgressRemote {
  ProgressSnapshot value = const ProgressSnapshot(revision: 'epub-r1');
  int writes = 0;
  @override
  Future<ProgressSnapshot> read(
    String book, {
    CancellationSignal? cancellation,
  }) async => value;
  @override
  Future<void> write(
    String book,
    ProgressSnapshot target, {
    CancellationSignal? cancellation,
  }) async {
    writes++;
    value = ProgressSnapshot(
      revision: target.revision,
      pageIndex: target.pageIndex,
      completed: target.completed,
      documentLocator: target.documentLocator,
      version: '$writes',
    );
  }
}

void main() {
  test(
    'same-position outbox coalescing preserves the furthest chapter fraction',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final manifest = ReaderManifest(
        accountId: 'a',
        bookId: 'b',
        revision: 'epub-r1',
        title: 'Book',
        documentType: 'application/epub+zip',
        pages: [PageDimensions(1, 1), PageDimensions(1, 1)],
      );
      final store = ProgressStore(db, 'a');
      await store.save(manifest, ReaderLocator(0, .8, locator(.8)));
      await store.save(manifest, ReaderLocator(0, .2, locator(.2)));
      expect((await store.pending()).single.documentLocator, locator(.8));
      expect(
        (await ReaderStore(db, 'a').locator(manifest)).documentLocator,
        locator(.2),
      );
    },
  );
  test('precise position and outbox persist atomically; duplicate events write nothing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final manifest = ReaderManifest(
      accountId: 'a',
      bookId: 'b',
      revision: 'epub-r1',
      title: 'Book',
      documentType: 'application/epub+zip',
      pages: [for (var i = 0; i < 4; i++) PageDimensions(1, 1)],
    );
    final store = ProgressStore(db, 'a');
    await store.save(manifest, ReaderLocator(1, .2, locator(.2)));
    final original = (await store.pending()).single;
    await store.save(manifest, ReaderLocator(1, .2, locator(.2)));
    expect((await store.pending()).single.sequence, original.sequence);
    expect(
      (await ReaderStore(db, 'a').locator(manifest)).documentLocator,
      locator(.2),
    );
    expect(
      (await ReaderStore(db, 'other').locator(manifest)).documentLocator,
      isNull,
    );
    final remote = Remote()
      ..value = ProgressSnapshot(
        revision: 'epub-r1',
        pageIndex: 1,
        documentLocator: locator(.1),
      );
    final sync = ProgressSync(
      store,
      remote,
      PageNetworkGate(),
      isCurrent: () => true,
    );
    addTearDown(sync.close);
    await sync.replay();
    expect(remote.writes, 1);
    expect(remote.value.documentLocator, locator(.2));
    expect(await store.pending(), isEmpty);
    await store.save(manifest, ReaderLocator(1, .4, locator(.4)));
    await sync.replay();
    expect(remote.writes, 2);
    expect(remote.value.documentLocator, locator(.4));
    await store.save(
      manifest,
      ReaderLocator(0, 0, locator(0)),
      operation: ProgressOperation.rewind,
    );
    remote.value = ProgressSnapshot(
      revision: 'epub-r1',
      pageIndex: 2,
      version: 'other-device',
      documentLocator: locator(.8),
    );
    await sync.replay();
    expect((await store.pending()).single.state, 'conflict');
    expect(remote.writes, 2);
  });
}
