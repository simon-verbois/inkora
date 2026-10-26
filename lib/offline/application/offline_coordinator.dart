import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/connection/application/session_controller.dart';
import '../../features/connection/domain/session.dart';
import '../../reader/application/reader_network_policy.dart';
import '../../reader/application/reader_providers.dart';
import '../../reader/data/reader_asset_store.dart';
import '../data/download_scheduler.dart';
import '../data/download_store.dart';
import '../data/download_retention_store.dart';
import '../data/progress_store.dart';
import '../data/progress_sync.dart';
import '../domain/progress.dart';
import 'background_transfer.dart';

final nativeForegroundProvider = FutureProvider<void>((ref) {
  ref.watch(sessionProvider.select((s) => s.session?.accountId));
  if (_initiallyBackgrounded()) return Future.value();
  return BackgroundTransfer().foreground();
});

bool _initiallyBackgrounded() {
  final state = WidgetsBinding.instance.lifecycleState;
  return state != null && state != AppLifecycleState.resumed;
}

final offlineCoordinatorProvider = FutureProvider<OfflineCoordinator?>((
  ref,
) async {
  final transport = ref.watch(activeConnectionTransportProvider);
  final state = ref.watch(
    sessionProvider.select((s) => (s.phase, s.session?.accountId)),
  );
  var alive = true;
  OfflineCoordinator? coordinator;
  ref.onDispose(() {
    alive = false;
    coordinator?.close();
  });
  await ref.watch(nativeForegroundProvider.future);
  if (!alive) return null;
  final bridge = BackgroundTransfer();
  if (state.$1 != SessionPhase.ready || state.$2 == null) {
    if (state.$1 != SessionPhase.restoring) {
      for (final account in await bridge.accounts()) {
        if (!alive) return null;
        await bridge.cancelAccount(account);
      }
    }
    return null;
  }
  for (final account in await bridge.accounts()) {
    if (!alive) return null;
    if (account != state.$2) await bridge.cancelAccount(account);
  }
  if (!alive) return null;
  final controller = ref.read(sessionProvider.notifier);
  final session = ref.read(sessionProvider).session!;
  final client = transport!;
  final database = await ref.watch(databaseProvider);
  final assets = await ref.watch(readerAssetStoreProvider);
  final support = await getApplicationSupportDirectory();
  if (!alive || controller.client != client) return null;
  final store = DownloadStore(
    database,
    session.accountId,
    Directory('${support.path}/download-staging'),
  );
  await store.loadSettings();
  final progress = ProgressStore(database, session.accountId);
  final gate = ref.watch(pageNetworkGateProvider);
  bool current() => alive && controller.client == client;
  coordinator = OfflineCoordinator(
    store,
    assets,
    session,
    DownloadScheduler.komga(store, assets, gate, client, current),
    ProgressSync(
      progress,
      KomgaProgressRemote(client, session.accountId),
      gate,
      isCurrent: current,
    ),
    BackgroundTransfer(),
    current,
    bookInUse: (book) => ref.read(activeReadingBooksProvider).contains(book),
  );
  await coordinator.start();
  if (!current()) {
    coordinator.close();
    return null;
  }
  return coordinator;
}, retry: (_, _) => null);

final downloadsProvider = StreamProvider<List<DownloadJob>>((ref) async* {
  final coordinator = await ref.watch(offlineCoordinatorProvider.future);
  if (coordinator != null) yield* coordinator.store.watch();
});
final downloadedBooksProvider = StreamProvider<List<DownloadedBook>>((
  ref,
) async* {
  final coordinator = await ref.watch(offlineCoordinatorProvider.future);
  if (coordinator == null) {
    yield [];
  } else {
    yield* coordinator.store.completedBooks();
  }
});

/// Identities with a completed download, for cover badges. Widgets select a
/// single `contains` result so unrelated downloads do not rebuild them.
final downloadedIdentitiesProvider = StreamProvider<Set<String>>((ref) async* {
  final coordinator = await ref.watch(offlineCoordinatorProvider.future);
  if (coordinator == null) {
    yield const <String>{};
  } else {
    yield* coordinator.store.completedIdentities();
  }
});

/// Completed downloads grouped by series (ebooks individually), with each
/// book's effective reading state and committed bytes. Re-queried only when a
/// job changes state or a book's reading classification changes.
final downloadedReadingSeriesProvider =
    StreamProvider.autoDispose<List<DownloadedSeries>>((ref) async* {
      final coordinator = await ref.watch(offlineCoordinatorProvider.future);
      if (coordinator == null) {
        yield [];
        return;
      }
      yield* coordinator.store.completedSeries(includeReadingStatus: true);
    });

/// Storage summary of the Downloads page and download settings. Recomputed
/// only when a job is added, removed or changes state: staged-page progress
/// writes do not re-run the aggregate query.
final downloadStorageProvider = FutureProvider.autoDispose<DownloadStorage?>((
  ref,
) async {
  ref.watch(
    downloadsProvider.select(
      (jobs) =>
          jobs.asData?.value
              .map((job) => '${job.id}:${job.state.name}')
              .join(',') ??
          '',
    ),
  );
  final coordinator = await ref.watch(offlineCoordinatorProvider.future);
  return coordinator?.store.storage();
});

final progressIntentsProvider = StreamProvider<List<ProgressIntent>>((
  ref,
) async* {
  final coordinator = await ref.watch(offlineCoordinatorProvider.future);
  if (coordinator != null) yield* coordinator.sync.store.watch();
});

/// Owns one account generation. Native transfers stop before foreground reader
/// admission; event-driven replay never blocks a local locator transaction.
final class OfflineCoordinator with WidgetsBindingObserver {
  OfflineCoordinator(
    this.store,
    this.assets,
    this.session,
    this.downloads,
    this.sync,
    this.background,
    this.isCurrent, {
    this.bookInUse = _notInUse,
  });
  final DownloadStore store;
  final ReaderAssetStore assets;
  final SavedSession session;
  final DownloadScheduler downloads;
  final ProgressSync sync;
  final BackgroundTransfer background;
  final bool Function() isCurrent;
  final bool Function(String) bookInUse;
  static bool _notInUse(String _) => false;
  Timer? _timer;
  StreamSubscription<({bool hasWork, int? dueAt})>? _progressSubscription;
  StreamSubscription<bool>? _downloadSubscription;
  bool _progressWork = false, _downloadWork = false;
  int _monitorGeneration = 0, _retryGeneration = 0;
  Future<void>? _replayWork;
  bool _closed = false, _backgrounded = false, _recovered = false;
  Future<void> _lifecycle = Future.value();
  bool get current => !_closed && isCurrent();
  Future<void> start() async {
    _backgrounded = _initiallyBackgrounded();
    WidgetsBinding.instance.addObserver(this);
    // An iOS background wake may create the engine while URLSession still owns
    // transfers. Recovery and foreground admission must wait for an actual resume.
    _lifecycle = _foreground();
    await _lifecycle;
  }

  /// Durable writes wake replay; only a queued head's due time arms a timer.
  void _startMonitoring() {
    if (!current || _backgrounded || _progressSubscription != null) return;
    final generation = ++_monitorGeneration;
    _progressSubscription = sync.store.watchReplaySchedule().listen((work) {
      if (!current || _backgrounded || generation != _monitorGeneration) return;
      _progressWork = work.hasWork;
      _updatePolicyWatch();
      _armReplay(work.dueAt);
    });
    _downloadSubscription = store.watchActiveWork().listen((active) {
      if (!current || _backgrounded || generation != _monitorGeneration) return;
      _downloadWork = active;
      _updatePolicyWatch();
    });
  }

  void _updatePolicyWatch() {
    if (!_progressWork && !_downloadWork) {
      unawaited(_policySubscription?.cancel());
      _policySubscription = null;
      _policy = null;
      return;
    }
    if (_policySubscription != null) return;
    final generation = _monitorGeneration;
    _policySubscription = ReaderNetworkPolicy.watch().listen((snapshot) {
      if (!current || _backgrounded || generation != _monitorGeneration) return;
      _policy = snapshot;
      unawaited(_tick().catchError((Object _) {}));
    });
  }

  void _stopMonitoring() {
    _monitorGeneration++;
    _retryGeneration++;
    _timer?.cancel();
    _timer = null;
    unawaited(_progressSubscription?.cancel());
    _progressSubscription = null;
    unawaited(_downloadSubscription?.cancel());
    _downloadSubscription = null;
    _progressWork = _downloadWork = false;
    unawaited(_policySubscription?.cancel());
    _policySubscription = null;
    _policy = null;
  }

  StreamSubscription<ReaderNetworkSnapshot>? _policySubscription;
  ReaderNetworkSnapshot? _policy;

  void _armReplay(int? dueAt) {
    _retryGeneration++;
    _timer?.cancel();
    _timer = null;
    if (!current ||
        _backgrounded ||
        _policy == null ||
        _policy!.paused ||
        sync.authenticationExpired ||
        _replayWork != null ||
        dueAt == null) {
      return;
    }
    final delay = dueAt - sync.now();
    _timer = Timer(Duration(milliseconds: delay < 0 ? 0 : delay), _wakeReplay);
  }

  void _wakeReplay() {
    _timer?.cancel();
    _timer = null;
    if (!current || _backgrounded || sync.paused || _replayWork != null) return;
    final work = _replayWork = sync.replay();
    unawaited(
      work.catchError((Object _) {}).whenComplete(() {
        _replayWork = null;
        if (!current || _backgrounded) return;
        final generation = ++_retryGeneration;
        // A fresh aggregate also catches writes made while this replay ran.
        unawaited(
          sync.store
              .nextReplayAt()
              .then((dueAt) {
                if (generation == _retryGeneration) _armReplay(dueAt);
              })
              .catchError((Object _) {}),
        );
      }),
    );
  }

  Future<void> _tick() async {
    if (!current || _backgrounded) return;
    final policy = _policy ?? await ReaderNetworkPolicy.current();
    if (!current || _backgrounded) return;
    await downloads.suspend(
      policy.paused || (store.wifiOnly && policy.constrained),
    );
    if (!current || _backgrounded) return;
    sync.paused = policy.paused;
    _wakeReplay();
  }

  Future<void> configure({required int quota, required bool wifiOnly}) async {
    await store.configure(quota: quota, wifiOnly: wifiOnly);
    await _tick();
  }

  Future<void> enqueue(String book) =>
      downloads.enqueue(book).then((_) => _tick());
  Future<void> pause(String job) async {
    await _stopNative();
    await downloads.pause(job);
  }

  Future<void> cancel(String job) async {
    await _stopNative();
    await downloads.cancel(job);
  }

  Future<void> _stopNative() async {
    await background.foreground();
    await _import();
    await background.cancelAccount(store.accountId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.resumed) {
      // Set the flag synchronously so an outstanding policy query cannot restart
      // Dart work during handoff. Serialize rapid pause/resume transitions.
      _backgrounded = state != AppLifecycleState.resumed;
      final toBackground = _backgrounded;
      if (toBackground) _stopMonitoring();
      _lifecycle = _lifecycle
          .then((_) => toBackground ? _handoff() : _foreground())
          .catchError((Object _) {});
    }
  }

  Future<void> _handoff() async {
    sync.paused = true;
    await downloads.suspend(true);
    if (!current || !_backgrounded) return;
    final policy = await ReaderNetworkPolicy.current();
    if (!current || policy.paused) return;
    final tasks = <Map<String, Object?>>[];
    for (final job in await store.jobs()) {
      if (job.state != DownloadState.queued) continue;
      final parts = await store.parts(job.id);
      for (var page = 0; page < job.manifest.assetCount; page++) {
        if (parts.containsKey(page)) continue;
        tasks.add({
          'id': '${job.id}-$page',
          'account': store.accountId,
          'job': job.id,
          'page': page,
          'path': '${store.file(job.id, page).path}.native',
          'maximumBytes': store.pageBudget(job.manifest, page),
          'url': session.endpoint
              .resolveApiPath(
                job.manifest.isDocument
                    ? 'api/v1/books/${Uri.encodeComponent(job.manifest.bookId)}/file'
                    : 'api/v1/books/${Uri.encodeComponent(job.manifest.bookId)}/pages/${page + 1}',
              )
              .toString(),
        });
        if (tasks.length == 128) break;
      }
      if (tasks.length == 128) break;
    }
    if (!current || !_backgrounded) return;
    try {
      await background.enqueue(
        tasks,
        headers: session.credentials.headers,
        wifiOnly: store.wifiOnly,
      );
    } finally {
      if (!current) await background.cancelAccount(store.accountId);
    }
  }

  Future<void> _foreground() async {
    if (!current || _backgrounded) return;
    await background.foreground();
    if (!current) return;
    await _import();
    await background.cancelAccount(store.accountId);
    if (!_recovered) {
      await background.excludeFromBackup([
        store.directory.path,
        assets.downloadDirectory.path,
      ]);
      await downloads.recover();
      await assets.recoverDownloads();
      await sync.store.recover();
      _recovered = true;
    }
    if (!_backgrounded) {
      // Launch/resume opportunities only: never delete a book during an active
      // reading session or create a background timer just for retention.
      final retention = DownloadRetentionStore(store.database, store.accountId);
      for (final candidate in await retention.due()) {
        if (!current || _backgrounded) break;
        // Recheck policy/progress after each asynchronous removal opportunity.
        if ((await retention.due(jobId: candidate.jobId)).isEmpty) continue;
        if (!current || _backgrounded) break;
        if (bookInUse(candidate.bookId)) continue;
        await downloads.cancel(candidate.jobId);
      }
      _startMonitoring();
      await _tick();
    }
  }

  Future<void> _import() async {
    for (final result in await background.results()) {
      if (!current) return;
      // An inactive account's native queue must never be imported into this one.
      if (result['account'] != store.accountId) continue;
      final id = result['id'] as String;
      final job = await store.job(result['job'] as String);
      try {
        if (job == null ||
            job.state == DownloadState.cancelled ||
            job.state == DownloadState.complete) {
          continue;
        }
        if (result['state'] != 'complete') {
          continue; // Foreground retry uses sanitized Dart errors.
        }
        final page = result['page'] as int;
        job.manifest.key(page);
        final path = '${store.file(job.id, page).path}.native';
        if (result['path'] != path) {
          throw const FormatException('Invalid native output');
        }
        final file = File(path);
        final length = await file.length();
        final expected = job.manifest.pages[page].sizeBytes;
        if (length < 1 ||
            length > store.pageBudget(job.manifest, page) ||
            (expected > 0 && length != expected) ||
            length != result['byteLength']) {
          throw const FormatException('Invalid native length');
        }
        final mediaType = result['mediaType'] as String;
        final inspected = await inspectDownloadAsset(
          file,
          mediaType,
          maximumBytes: store.pageBudget(job.manifest, page),
        );
        final checksum = inspected.checksum;
        if (result['checksum'] != null && result['checksum'] != checksum) {
          throw const FormatException('Invalid native checksum');
        }
        if (!current) return;
        final ready = await file.rename(store.file(job.id, page).path);
        await store.record(
          job.id,
          page,
          DownloadAsset(ready, checksum, mediaType, length),
        );
      } catch (_) {
        /* Invalid stages are never published; foreground restarts the asset. */
      } finally {
        await background.acknowledge(id);
      }
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _stopMonitoring();
    WidgetsBinding.instance.removeObserver(this);
    sync.close();
    downloads.close();
    unawaited(
      background.cancelAccount(store.accountId).catchError((Object _) {}),
    );
  }
}
