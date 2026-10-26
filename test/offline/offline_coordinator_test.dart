import 'dart:io';
import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/connection_fakes.dart';
import '../support/reader_fakes.dart';
import 'progress_sync_test.dart' show FakeRemote;

class _Queries extends QueryInterceptor {
  int selects = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late AppDatabase database;
  late OfflineCoordinator coordinator;
  late ProgressStore progress;
  late FakeRemote remote;
  late _Queries queries;
  var policyCalls = 0, paused = false, current = true;
  final previousInterval = ReaderNetworkPolicy.pollInterval;

  Future<void> settle([int milliseconds = 60]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));
  Future<void> save(
    int page, {
    String book = 'reader-book',
    ProgressOperation operation = ProgressOperation.advance,
  }) => progress.save(
    readerManifest(book: book),
    ReaderLocator(page, 0),
    operation: operation,
  );

  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    ReaderNetworkPolicy.pollInterval = const Duration(milliseconds: 15);
    policyCalls = 0;
    paused = false;
    current = true;
    messenger.setMockMethodCallHandler(ReaderNetworkPolicy.channel, (
      call,
    ) async {
      if (call.method == 'events') return false;
      policyCalls++;
      return {'metered': false, 'dataSaver': paused};
    });
    messenger.setMockMethodCallHandler(
      BackgroundTransfer.channel,
      (call) async => call.method == 'results' ? [] : null,
    );
    root = await Directory.systemTemp.createTemp('inkora-coordinator-');
    queries = _Queries();
    database = AppDatabase(NativeDatabase.memory().interceptWith(queries));
    final assets = ReaderAssetStore(
      database,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    final downloads = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/staging'),
    );
    final gate = PageNetworkGate();
    progress = ProgressStore(database, 'reader-account');
    remote = FakeRemote();
    coordinator = OfflineCoordinator(
      downloads,
      assets,
      savedSession,
      DownloadScheduler(
        downloads,
        assets,
        gate,
        loadManifest: (book, _) async => readerManifest(book: book),
        transfer: (_, _, _, _, _) => throw StateError('No implicit transfer'),
        isCurrent: () => current,
      ),
      ProgressSync(progress, remote, gate, isCurrent: () => current),
      BackgroundTransfer(),
      () => current,
    );
  });
  tearDown(() async {
    coordinator.close();
    await coordinator.sync.idle;
    await coordinator.downloads.idle;
    await coordinator.assets.idle;
    await settle(10);
    await database.close();
    await root.delete(recursive: true);
    messenger.setMockMethodCallHandler(ReaderNetworkPolicy.channel, null);
    messenger.setMockMethodCallHandler(BackgroundTransfer.channel, null);
    ReaderNetworkPolicy.pollInterval = previousInterval;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('idle queues perform no periodic queries or policy polling', () async {
    await coordinator.start();
    await settle();
    final before = (queries.selects, policyCalls);
    await settle(5100);
    expect((queries.selects, policyCalls), before);
    expect(remote.writes, isEmpty);
  });

  test('local outbox writes wake immediately and return to idle after acknowledgement', () async {
    await coordinator.start();
    await settle();
    await save(2);
    await settle();
    expect(remote.writes.single.pageIndex, 2);
    expect(await progress.pending(), isEmpty);
    await settle();
    final before = (queries.selects, policyCalls);
    await settle();
    expect((queries.selects, policyCalls), before);
  });

  test(
    'a queued head waits for its deadline and reschedules changed backoff',
    () async {
      await save(2);
      final intent = (await progress.pending()).single;
      await progress.state(
        intent,
        'queued',
        retryAt: DateTime.now().millisecondsSinceEpoch + 400,
      );
      await coordinator.start();
      await settle();
      expect(remote.writes, isEmpty);
      await progress.state(
        intent,
        'queued',
        retryAt: DateTime.now().millisecondsSinceEpoch + 80,
      );
      await settle(160);
      expect(remote.writes.single.pageIndex, 2);
      expect(await progress.pending(), isEmpty);
    },
  );

  test('progress saved during an upload is durable immediately and wakes a following replay', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    remote.onRead = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
      return remote.snapshot;
    };
    try {
      await coordinator.start();
      await save(1);
      await entered.future.timeout(const Duration(seconds: 2));
      await save(2);
      expect(remote.writes, isEmpty);
      expect((await progress.pending()).last.pageIndex, 2);
    } finally {
      release.complete();
    }
    await settle(120);
    expect(remote.writes.map((write) => write.pageIndex), [1, 2]);
    expect(await progress.pending(), isEmpty);
  });

  test('conflicted heads block later book intents without keeping idle polling alive', () async {
    await save(1);
    final head = (await progress.pending()).single;
    await progress.state(head, 'conflict', remote: remote.snapshot);
    await save(2, operation: ProgressOperation.complete);
    expect(await progress.nextReplayAt(), isNull);
    await coordinator.start();
    await settle();
    final before = (queries.selects, policyCalls);
    await settle();
    expect((queries.selects, policyCalls), before);
    expect(remote.writes, isEmpty);
    await progress.state(head, 'queued');
    await settle();
    expect(await progress.pending(), isEmpty);
  });

  test(
    'foreign account changes never schedule this account or send its progress',
    () async {
      await coordinator.start();
      final foreign = ProgressStore(database, 'other-account');
      await foreign.save(
        readerManifest(account: 'other-account'),
        ReaderLocator(2, 0),
      );
      await settle();
      expect(remote.writes, isEmpty);
      final before = policyCalls;
      await settle();
      expect(policyCalls, before);
      expect(await foreign.pending(), hasLength(1));
    },
  );

  test(
    'Data Saver pauses pending replay and a policy change resumes it',
    () async {
      paused = true;
      await coordinator.start();
      await save(2);
      await settle();
      expect(remote.writes, isEmpty);
      paused = false;
      await settle();
      expect(remote.writes.single.pageIndex, 2);
      expect(await progress.pending(), isEmpty);
    },
  );

  test(
    'backgrounding cancels retry and policy work; resume processes a due head',
    () async {
      await save(2);
      await progress.state(
        (await progress.pending()).single,
        'queued',
        retryAt: DateTime.now().millisecondsSinceEpoch + 200,
      );
      await coordinator.start();
      await settle();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle();
      final before = policyCalls;
      await settle(200);
      expect(policyCalls, before);
      expect(remote.writes, isEmpty);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(100);
      expect(remote.writes.single.pageIndex, 2);
    },
  );

  test(
    'account disposal cancels scheduled retries and all policy callbacks',
    () async {
      await save(2);
      await progress.state(
        (await progress.pending()).single,
        'queued',
        retryAt: DateTime.now().millisecondsSinceEpoch + 150,
      );
      await coordinator.start();
      await settle();
      current = false;
      coordinator.close();
      await settle();
      final before = policyCalls;
      await settle(150);
      expect(policyCalls, before);
      expect(remote.writes, isEmpty);
      expect(await progress.pending(), hasLength(1));
    },
  );

  test('policy fallback observes queued downloads and stops when the last job pauses', () async {
    paused = true;
    await coordinator.start();
    final job = await coordinator.store.enqueue(readerManifest());
    await settle();
    final activeCalls = policyCalls;
    await settle();
    expect(policyCalls, greaterThan(activeCalls));
    await coordinator.pause(job);
    await settle();
    final idleCalls = policyCalls;
    await settle();
    expect(policyCalls, idleCalls);
    expect(await coordinator.store.stateOf(job), DownloadState.paused);
  });
}
