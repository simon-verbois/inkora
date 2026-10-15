import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../support/reader_fakes.dart';

class FakeRemote implements ProgressRemote {
  ProgressSnapshot snapshot = const ProgressSnapshot(revision: 'revision-a');
  final writes = <ProgressSnapshot>[];
  Future<void> Function()? onWrite;
  Future<ProgressSnapshot> Function()? onRead;
  int version = 0;
  @override
  Future<ProgressSnapshot> read(
    String book, {
    CancellationSignal? cancellation,
  }) async => onRead == null ? snapshot : onRead!();
  @override
  Future<void> write(
    String book,
    ProgressSnapshot target, {
    CancellationSignal? cancellation,
  }) async {
    writes.add(target);
    snapshot = ProgressSnapshot(
      revision: target.revision,
      pageIndex: target.pageIndex,
      completed: target.completed,
      version: '${++version}',
    );
    await onWrite?.call();
  }
}

void main() {
  late AppDatabase database;
  late ProgressStore store;
  late FakeRemote remote;
  late ProgressSync sync;
  var current = true;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = ProgressStore(database, 'reader-account');
    remote = FakeRemote();
    current = true;
    sync = ProgressSync(
      store,
      remote,
      PageNetworkGate(),
      isCurrent: () => current,
      now: () => 10000,
      jitter: () => .5,
    );
  });
  tearDown(() async {
    sync.close();
    await sync.idle;
    await database.close();
  });
  Future<void> save(
    int page, [
    ProgressOperation operation = ProgressOperation.advance,
  ]) => store.save(
    readerManifest(),
    ReaderLocator(page, .3),
    operation: operation,
  );

  test(
    'locator and outbox roll back together if durable intent insertion fails',
    () async {
      await database.customStatement(
        "CREATE TRIGGER reject_intent BEFORE INSERT ON progress_events BEGIN SELECT RAISE(ABORT, 'storage failure'); END",
      );
      await expectLater(save(2), throwsA(isA<SqliteException>()));
      expect(await database.select(database.readerPositions).get(), isEmpty);
      expect(await store.pending(), isEmpty);
      expect(await database.select(database.progressHeads).get(), isEmpty);
    },
  );
  test('advance coalesces monotonically while local backwards navigation keeps its exact fraction', () async {
    await save(2);
    await save(1);
    final events = await store.pending();
    expect(events.length, 1);
    expect(events.single.sequence, 2);
    expect(events.single.pageIndex, 2);
    final locator = await ReaderStore(
      database,
      'reader-account',
    ).locator(readerManifest());
    expect(locator.pageIndex, 1);
    expect(locator.fraction, .3);
    await sync.replay();
    expect(remote.writes.single.pageIndex, 2);
    expect(await store.pending(), isEmpty);
  });
  test('advance, deliberate rewind, and subsequent advance preserve ordered barriers', () async {
    remote.snapshot = const ProgressSnapshot(
      revision: 'revision-a',
      pageIndex: 0,
      version: 'old',
    );
    await store.observe('reader-book', remote.snapshot);
    await save(2);
    await save(0, ProgressOperation.rewind);
    await save(1);
    expect((await store.pending()).length, 3);
    await sync.replay();
    expect(remote.writes.map((s) => s.pageIndex), [2, 0, 1]);
    expect(await store.pending(), isEmpty);
  });
  test('ambiguous committed PATCH is acknowledged by read-back instead of duplicated', () async {
    remote.onWrite = () async {
      throw const ApiFailure(FailureKind.transientNetwork, 'Timeout');
    };
    await save(2);
    await sync.replay();
    await sync.replay();
    expect(remote.writes.length, 1);
    expect(await store.pending(), isEmpty);
  });
  test('acknowledging a sent sequence preserves an update arriving during its request', () async {
    final entered = Completer<void>(), release = Completer<void>();
    remote.onWrite = () async {
      entered.complete();
      await release.future;
    };
    await save(1);
    final replay = sync.replay();
    await entered.future;
    await save(2);
    release.complete();
    await replay;
    final events = await store.pending();
    expect(events.length, 1);
    expect(events.single.sequence, 2);
    remote.onWrite = null;
    await sync.replay();
    expect(remote.writes.map((p) => p.pageIndex), [1, 2]);
    expect(await store.pending(), isEmpty);
  });
  test(
    'remote advance wins ordinary reconciliation without any backwards write',
    () async {
      remote.snapshot = const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 3,
        completed: true,
        version: 'future',
      );
      await save(1);
      await sync.replay();
      expect(remote.writes, isEmpty);
      expect(await store.pending(), isEmpty);
    },
  );
  test('offline rewind divergence retains both candidates until a local choice is made', () async {
    await store.observe(
      'reader-book',
      const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 1,
        version: 'baseline',
      ),
    );
    await save(0, ProgressOperation.rewind);
    remote.snapshot = const ProgressSnapshot(
      revision: 'revision-a',
      pageIndex: 2,
      version: 'changed',
    );
    await sync.replay();
    final conflict = (await store.pending()).single;
    expect(conflict.state, 'conflict');
    expect(conflict.remote!.pageIndex, 2);
    expect(remote.writes, isEmpty);
    await store.resolve(conflict, keepLocal: true);
    await sync.replay();
    expect(remote.writes.single.pageIndex, 0);
    expect(await store.pending(), isEmpty);
  });
  test('unread reset with unknown baseline asks for a choice; server choice restores locator', () async {
    await save(0, ProgressOperation.markUnread);
    remote.snapshot = const ProgressSnapshot(
      revision: 'revision-a',
      pageIndex: 2,
      version: 'other',
    );
    await sync.replay();
    final conflict = (await store.pending()).single;
    expect(conflict.state, 'conflict');
    await store.resolve(conflict, keepLocal: false);
    expect(
      (await ReaderStore(database, 'reader-account').locator(readerManifest()))
          .pageIndex,
      2,
    );
    expect(remote.writes, isEmpty);
    expect(await store.pending(), isEmpty);
  });
  test(
    'deliberate unread and complete replay separately from ordinary advances',
    () async {
      remote.snapshot = const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 2,
        version: 'v1',
      );
      await store.observe('reader-book', remote.snapshot);
      await save(0, ProgressOperation.markUnread);
      await save(3, ProgressOperation.complete);
      await sync.replay();
      expect(remote.writes.map((p) => p.pageIndex), [null, 3]);
      expect(remote.writes.last.completed, isTrue);
      expect(await store.pending(), isEmpty);
    },
  );
  test('different revisions stop comparison and reject an unmapped local conflict choice', () async {
    await save(2);
    remote.snapshot = const ProgressSnapshot(
      revision: 'new-revision',
      pageIndex: 1,
    );
    await sync.replay();
    final conflict = (await store.pending()).single;
    expect(conflict.state, 'conflict');
    expect(remote.writes, isEmpty);
    await expectLater(
      store.resolve(conflict, keepLocal: true),
      throwsStateError,
    );
    await store.resolve(conflict, keepLocal: false);
    expect(
      (await ReaderStore(
        database,
        'reader-account',
      ).locator(readerManifest(revision: 'new-revision'))).pageIndex,
      1,
    );
  });
  test(
    'a concurrent server change after PATCH is retained as a conflict',
    () async {
      remote.onWrite = () async {
        remote.snapshot = const ProgressSnapshot(
          revision: 'revision-a',
          pageIndex: 0,
          version: 'concurrent',
        );
      };
      await save(2);
      await sync.replay();
      expect((await store.pending()).single.state, 'conflict');
      expect((await store.pending()).single.remote!.pageIndex, 0);
    },
  );
  test(
    'authentication expiry pauses replay without discarding events',
    () async {
      var reads = 0;
      remote.onRead = () async {
        reads++;
        throw const ApiFailure(FailureKind.authentication, 'Expired');
      };
      await save(1);
      await sync.replay();
      await sync.replay();
      expect(sync.authenticationExpired, isTrue);
      expect(reads, 1);
      final event = (await store.pending()).single;
      expect(event.state, 'queued');
      expect(event.attempt, 1);
      expect(event.retryAt, 12000);
    },
  );
  test('account switch rejects late read/write completion and never acknowledges another account', () async {
    final entered = Completer<void>(), release = Completer<void>();
    remote.onWrite = () async {
      entered.complete();
      await release.future;
    };
    await save(1);
    final replay = sync.replay();
    await entered.future;
    current = false;
    final other = ProgressStore(database, 'other');
    await other.save(readerManifest(account: 'other'), ReaderLocator(3));
    release.complete();
    await replay;
    expect((await store.pending()).single.state, 'sending');
    expect((await other.pending()).single.pageIndex, 3);
    await store.recover();
    expect((await store.pending()).single.state, 'queued');
    expect(remote.writes.length, 1);
  });
  test('restart preserves local position, pending account events, and interrupted-write read-back', () async {
    final folder = await Directory.systemTemp.createTemp('inkora-outbox-');
    addTearDown(() => folder.delete(recursive: true));
    await database.close();
    database = AppDatabase(NativeDatabase(File('${folder.path}/state.sqlite')));
    store = ProgressStore(database, 'reader-account');
    await save(2);
    await store.state((await store.pending()).single, 'sending');
    await database.close();
    database = AppDatabase(NativeDatabase(File('${folder.path}/state.sqlite')));
    store = ProgressStore(database, 'reader-account');
    await store.recover();
    remote.snapshot = const ProgressSnapshot(
      revision: 'revision-a',
      pageIndex: 2,
      version: 'committed',
    );
    sync.close();
    sync = ProgressSync(
      store,
      remote,
      PageNetworkGate(),
      isCurrent: () => true,
    );
    await sync.replay();
    expect(remote.writes, isEmpty);
    expect(await store.pending(), isEmpty);
    expect(
      (await ReaderStore(database, 'reader-account').locator(readerManifest()))
          .pageIndex,
      2,
    );
    expect(await ProgressStore(database, 'other').pending(), isEmpty);
  });
  test('acknowledging a remote advance cannot erase the baseline of an offline reset', () async {
    await store.observe(
      'reader-book',
      const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 1,
        version: 'known',
      ),
    );
    await save(1);
    await save(0, ProgressOperation.markUnread);
    remote.snapshot = const ProgressSnapshot(
      revision: 'revision-a',
      pageIndex: 2,
      version: 'another-client',
    );
    await sync.replay();
    expect(remote.writes, isEmpty);
    final pending = (await store.pending()).single;
    expect(pending.state, 'conflict');
    expect(pending.baseline!.version, 'known');
  });
  test(
    'an unknown baseline remains unknown through a preceding ordinary write',
    () async {
      await save(1);
      await save(0, ProgressOperation.rewind);
      await sync.replay();
      expect(remote.writes.length, 1);
      final pending = (await store.pending()).single;
      expect(pending.state, 'conflict');
      expect(pending.baseline, isNull);
    },
  );
  test(
    'server version changes cause conflict even when timestamps run backwards',
    () async {
      await store.observe(
        'reader-book',
        const ProgressSnapshot(
          revision: 'revision-a',
          pageIndex: 2,
          version: '2099-01-01T00:00:00Z',
        ),
      );
      await save(0, ProgressOperation.rewind);
      remote.snapshot = const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 2,
        version: '1900-01-01T00:00:00Z',
      );
      await sync.replay();
      expect((await store.pending()).single.state, 'conflict');
      expect(remote.writes, isEmpty);
    },
  );
  test(
    'a rewind to the last raster page reconciles inferred completion',
    () async {
      await store.observe('reader-book', remote.snapshot);
      await save(3, ProgressOperation.rewind);
      await sync.replay();
      expect(remote.writes.single.completed, isTrue);
      expect(await store.pending(), isEmpty);
    },
  );
  test('first online manifest imports server position without creating an outbox or replacing local intent', () async {
    await store.seedServerLocator(
      readerManifest(),
      const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 2,
        version: 'server',
      ),
    );
    expect(
      (await ReaderStore(database, 'reader-account').locator(readerManifest()))
          .pageIndex,
      2,
    );
    expect(await store.pending(), isEmpty);
    await save(0, ProgressOperation.rewind);
    await store.seedServerLocator(
      readerManifest(),
      const ProgressSnapshot(
        revision: 'revision-a',
        pageIndex: 3,
        completed: true,
        version: 'new-server',
      ),
    );
    expect(
      (await ReaderStore(database, 'reader-account').locator(readerManifest()))
          .pageIndex,
      0,
    );
    expect((await store.pending()).single.baseline!.version, 'server');
  });
}
