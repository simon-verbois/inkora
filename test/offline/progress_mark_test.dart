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

/// Server double keyed by book; a write behaves like Komga's PATCH/DELETE.
class BooksRemote implements ProgressRemote {
  final books = <String, ProgressSnapshot>{};
  final writes = <(String, ProgressSnapshot)>[];
  int version = 0;
  bool offline = false;
  @override
  Future<ProgressSnapshot> read(
    String book, {
    CancellationSignal? cancellation,
  }) async {
    if (offline) throw StateError('offline');
    return books[book] ?? const ProgressSnapshot(revision: 'server-r1');
  }

  @override
  Future<void> write(
    String book,
    ProgressSnapshot target, {
    CancellationSignal? cancellation,
  }) async {
    writes.add((book, target));
    books[book] = target.completed
        ? ProgressSnapshot(
            revision: target.revision,
            pageIndex: 29,
            completed: true,
            version: 'v${++version}',
          )
        : target.pageIndex == null
        ? ProgressSnapshot(revision: target.revision)
        : ProgressSnapshot(
            revision: target.revision,
            pageIndex: target.pageIndex,
            version: 'v${++version}',
          );
  }
}

const unreadServer = ProgressSnapshot(revision: ProgressIntent.anyRevision);

ProgressMark mark(String book, {ProgressSnapshot server = unreadServer}) =>
    ProgressMark(bookId: book, pageCount: 30, server: server);

void main() {
  late AppDatabase database;
  late ProgressStore store;
  late BooksRemote remote;
  late ProgressSync sync;
  var current = true;
  var now = 10000;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = ProgressStore(database, 'account-a');
    remote = BooksRemote();
    current = true;
    now = 10000;
    sync = ProgressSync(
      store,
      remote,
      PageNetworkGate(),
      isCurrent: () => current,
      now: () => now,
      jitter: () => .5,
    );
  });
  tearDown(() async {
    sync.close();
    await sync.idle;
    await database.close();
  });

  test('catalogue marks queue in one transaction without a manifest', () async {
    final queued = await store.mark([
      mark('b1'),
      mark('b2'),
      mark('b3'),
    ], read: true);
    expect(queued, 3);
    final pending = await store.pending();
    expect(pending.map((e) => e.bookId), ['b1', 'b2', 'b3']);
    for (final event in pending) {
      expect(event.operation, ProgressOperation.complete);
      expect(event.revision, ProgressIntent.anyRevision);
      expect(event.anyContent, isTrue);
      expect(event.pageIndex, 29);
      expect(event.pageCount, 30);
      expect(event.state, 'queued');
    }
    // A repeated mark is not written again (no unchanged writes).
    expect(await store.mark([mark('b1')], read: true), 0);
    expect((await store.pending()).length, 3);
    // The filtered-catalogue classification follows immediately.
    final states = await database.select(database.bookReadingStates).get();
    expect(states.map((s) => s.status).toSet(), {'completed'});
  });

  test('a failing insert rolls back the whole batch', () async {
    await database.customStatement(
      "CREATE TRIGGER reject_b2 BEFORE INSERT ON progress_events WHEN NEW.book_id='b2' BEGIN SELECT RAISE(ABORT, 'storage failure'); END",
    );
    await expectLater(
      store.mark([mark('b1'), mark('b2')], read: true),
      throwsA(isA<SqliteException>()),
    );
    expect(await store.pending(), isEmpty);
    expect(await database.select(database.progressHeads).get(), isEmpty);
  });

  test('replay binds a catalogue completion to the server revision and sends completed without a page', () async {
    remote.books['b1'] = const ProgressSnapshot(
      revision: 'server-r7',
      pageIndex: 4,
      version: 'old',
    );
    await store.mark([mark('b1')], read: true);
    await sync.replay();
    final (book, target) = remote.writes.single;
    expect(book, 'b1');
    expect(target.revision, 'server-r7');
    expect(target.completed, isTrue);
    expect(target.pageIndex, isNull);
    expect(await store.pending(), isEmpty);
    final head = await database.select(database.progressHeads).getSingle();
    expect(ProgressSnapshot.decode(head.baseline!).completed, isTrue);
  });

  test('offline marks stay queued and replay later', () async {
    remote.offline = true;
    await store.mark([mark('b1'), mark('b2')], read: true);
    await sync.replay();
    expect(remote.writes, isEmpty);
    final retried = await store.pending();
    expect(retried.every((e) => e.state == 'queued' && e.attempt == 1), isTrue);
    remote.offline = false;
    now += 60000;
    await sync.replay();
    expect(remote.writes.map((w) => w.$1), ['b1', 'b2']);
    expect(await store.pending(), isEmpty);
  });

  test(
    'mark unread from the displayed catalogue state resets server progress',
    () async {
      const displayed = ProgressSnapshot(
        revision: ProgressIntent.anyRevision,
        pageIndex: 29,
        completed: true,
        version: 'v-server',
      );
      remote.books['b1'] = const ProgressSnapshot(
        revision: 'server-r1',
        pageIndex: 29,
        completed: true,
        version: 'v-server',
      );
      await store.mark([mark('b1', server: displayed)], read: false);
      await sync.replay();
      final (_, target) = remote.writes.single;
      expect(target.pageIndex, isNull);
      expect(target.completed, isFalse);
      expect(remote.books['b1']!.pageIndex, isNull);
      expect(await store.pending(), isEmpty);
    },
  );

  test('mark unread conflicts when another client changed progress since the displayed state', () async {
    const displayed = ProgressSnapshot(
      revision: ProgressIntent.anyRevision,
      pageIndex: 9,
      version: 'v-seen',
    );
    remote.books['b1'] = const ProgressSnapshot(
      revision: 'server-r1',
      pageIndex: 20,
      version: 'v-other-device',
    );
    await store.mark([mark('b1', server: displayed)], read: false);
    await sync.replay();
    expect(remote.writes, isEmpty);
    final conflict = (await store.pending()).single;
    expect(conflict.state, 'conflict');
    expect(conflict.remote!.pageIndex, 20);
    // Keeping the local intent is allowed without a revision remap.
    await store.resolve(conflict, keepLocal: true);
    await sync.replay();
    expect(remote.books['b1']!.pageIndex, isNull);
    expect(await store.pending(), isEmpty);
  });

  test('server choice resolves a catalogue conflict without writing', () async {
    remote.books['b1'] = const ProgressSnapshot(
      revision: 'server-r1',
      pageIndex: 20,
      version: 'v-other-device',
    );
    await store.mark([
      mark(
        'b1',
        server: const ProgressSnapshot(
          revision: ProgressIntent.anyRevision,
          pageIndex: 3,
          version: 'v-seen',
        ),
      ),
    ], read: false);
    await sync.replay();
    final conflict = (await store.pending()).single;
    await store.resolve(conflict, keepLocal: false);
    expect(await store.pending(), isEmpty);
    expect(remote.writes, isEmpty);
  });

  test(
    'an observed device baseline takes precedence over the catalogue state',
    () async {
      const observed = ProgressSnapshot(
        revision: 'server-r1',
        pageIndex: 12,
        version: 'v-observed',
      );
      await store.observe('b1', observed);
      remote.books['b1'] = observed;
      await store.mark([
        mark(
          'b1',
          server: const ProgressSnapshot(
            revision: ProgressIntent.anyRevision,
            pageIndex: 2,
            version: 'v-stale-catalogue',
          ),
        ),
      ], read: false);
      expect(
        ProgressSnapshot.decode(
          (await store.pending()).single.baseline!.encode(),
        ).version,
        'v-observed',
      );
      await sync.replay();
      expect(remote.books['b1']!.pageIndex, isNull);
      expect(await store.pending(), isEmpty);
    },
  );

  test('unread rewinds the exact local reader position', () async {
    final manifest = ReaderManifest(
      accountId: 'account-a',
      bookId: 'b1',
      revision: 'server-r1',
      title: 'Book',
      pages: [for (var i = 0; i < 30; i++) PageDimensions(1, 1)],
    );
    await store.save(manifest, ReaderLocator(12, .4));
    await store.mark([mark('b1')], read: false);
    final locator = await ReaderStore(database, 'account-a').locator(manifest);
    expect(locator.pageIndex, 0);
    expect(locator.fraction, 0);
    final pending = await store.pending();
    expect(pending.last.operation, ProgressOperation.markUnread);
    expect(pending.last.sequence, 2);
  });

  test(
    'marks are isolated per account and a switched account sends nothing',
    () async {
      final other = ProgressStore(database, 'account-b');
      await store.mark([mark('b1')], read: true);
      expect(await other.pending(), isEmpty);
      current = false;
      await sync.replay();
      expect(remote.writes, isEmpty);
      expect((await store.pending()).single.state, 'queued');
      final foreign = (await store.pending()).single;
      expect(
        () => ProgressStore(database, 'account-b').state(foreign, 'sending'),
        throwsArgumentError,
      );
    },
  );

  test('catalogue baseline matching ignores revisions but not progress', () {
    const catalogue = ProgressSnapshot(
      revision: ProgressIntent.anyRevision,
      pageIndex: 5,
      version: 'v1',
    );
    expect(
      matchesBaseline(
        const ProgressSnapshot(revision: 'r9', pageIndex: 5, version: 'v1'),
        catalogue,
      ),
      isTrue,
    );
    expect(
      matchesBaseline(
        const ProgressSnapshot(revision: 'r9', pageIndex: 6, version: 'v1'),
        catalogue,
      ),
      isFalse,
    );
    expect(
      matchesBaseline(
        const ProgressSnapshot(revision: 'r9', pageIndex: 5, version: 'v2'),
        catalogue,
      ),
      isFalse,
    );
    expect(
      matchesBaseline(
        const ProgressSnapshot(revision: 'r9', completed: true, pageIndex: 5),
        catalogue,
      ),
      isFalse,
    );
    expect(
      matchesBaseline(
        const ProgressSnapshot(revision: 'r1', pageIndex: 5, version: 'v1'),
        const ProgressSnapshot(revision: 'r2', pageIndex: 5, version: 'v1'),
      ),
      isFalse,
    );
  });
}
