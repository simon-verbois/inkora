import 'download_progress.dart';

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/errors/failure_kind.dart';
import '../../core/network/komga/api_failure.dart';
import '../../core/network/komga/komga_client.dart';
import '../../reader/data/komga_reader_remote.dart';
import '../../reader/data/page_network_gate.dart';
import '../../reader/data/reader_asset_store.dart';
import '../../reader/domain/page_source.dart';
import '../../reader/domain/reader_manifest.dart';
import 'download_store.dart';

typedef DownloadTransfer =
    Future<({String mediaType, int byteLength})> Function(
      ReaderManifest manifest,
      int page,
      File file,
      CancelToken token,
      int maximumBytes,
    );

/// Concurrent page transfers per job (within the shared network gate).
const downloadPageConcurrency = 2;

typedef DownloadManifestLoader = Future<ReaderManifest> Function(
  String book,
  CancelToken token,
);

final class DownloadScheduler {
  DownloadScheduler(
    this.store,
    this.assets,
    this.gate, {
    required this.loadManifest,
    required this.transfer,
    required this.isCurrent,
    DownloadProgress? progress,
  }) : progress = progress ?? DownloadProgress();
  factory DownloadScheduler.komga(
    DownloadStore store,
    ReaderAssetStore assets,
    PageNetworkGate gate,
    KomgaClient client,
    bool Function() current,
  ) {
    final progress = DownloadProgress();
    return DownloadScheduler(
      store,
      assets,
      gate,
      loadManifest: (book, token) =>
          KomgaReaderRemote.loadManifest(client, store.accountId, book, token),
      transfer: (manifest, page, file, token, budget) {
        final job = store.id(manifest);
        return client.pageToFile(
          manifest.bookId,
          page,
          file,
          cancelToken: token,
          maximumBytes: budget,
          original: manifest.isDocument,
          onProgress: (received, total) => progress.received(
            job,
            page,
            received,
            total > 0 ? total : manifest.pages[page].sizeBytes,
          ),
        );
      },
      progress: progress,
      isCurrent: current,
    );
  }
  final DownloadProgress progress;

  final DownloadStore store;
  final ReaderAssetStore assets;
  final PageNetworkGate gate;
  final DownloadManifestLoader loadManifest;
  final DownloadTransfer transfer;
  final bool Function() isCurrent;
  Future<void>? _work;
  CancelToken? _token;
  CancellationController? _signal;
  String? _active;
  final _enqueuing = <CancelToken>{};
  bool _closed = false, _suspended = false;
  Timer? _retry;
  Future<void> get idle => _work ?? Future.value();
  bool get current => !_closed && isCurrent();

  Future<void> recover() async {
    await store.recover();
    for (final job in await store.jobs()) {
      if (job.state == DownloadState.cancelled ||
          job.state == DownloadState.complete ||
          !await assets.isDownloaded(job.manifest)) {
        continue;
      }
      final intact = await assets.verifyDownloadedManifest(job.manifest);
      if (intact) {
        await store.state(job.id, DownloadState.complete);
        await store.clean(job.id);
      }
    }
  }

  Future<String> enqueue(String book) async {
    if (!current) throw StateError('Download session closed');
    final token = CancelToken();
    final signal = CancellationController();
    final request = PageRequest(
      priority: PagePriority.download,
      onForegroundDemand: token.cancel,
    );
    token.whenCancel.then((_) => signal.cancel());
    _enqueuing.add(token);
    var acquired = false;
    try {
      await gate.acquire(signal, request);
      acquired = true;
      final manifest = await loadManifest(book, token);
      if (!current || token.isCancelled) {
        throw StateError('Download session closed');
      }
      final id = await store.enqueue(manifest);
      kick();
      return id;
    } finally {
      if (acquired) gate.release(request);
      _enqueuing.remove(token);
    }
  }

  void kick() {
    if (_work != null || !current || _suspended) return;
    _retry?.cancel();
    final work = _run();
    _work = work;
    unawaited(
      work
          .whenComplete(() {
            _work = null;
            unawaited(_armRetry().catchError((Object _) {}));
          })
          .catchError((Object _) {}),
    );
  }

  /// Wake only for queued work, at its backoff time; an idle queue arms nothing.
  Future<void> _armRetry() async {
    if (!current || _suspended) return;
    final next = await store.nextQueuedAt();
    if (next == null || !current || _suspended || _work != null) return;
    final delay = next - DateTime.now().millisecondsSinceEpoch;
    _retry?.cancel();
    _retry = Timer(
      Duration(milliseconds: delay.clamp(250, 5 * 60 * 1000)),
      kick,
    );
  }

  Future<void> suspend(bool value) async {
    _suspended = value;
    if (value) {
      _token?.cancel();
      _signal?.cancel();
      await idle;
    } else {
      kick();
    }
  }

  Future<void> pause(String id) async {
    await store.state(id, DownloadState.paused);
    if (_active == id) {
      _token?.cancel();
      _signal?.cancel();
      await idle;
    }
  }

  Future<void> resume(String id) async {
    final job = await store.job(id);
    if (job == null ||
        job.state == DownloadState.complete ||
        job.state == DownloadState.cancelled) {
      return;
    }
    await store.state(id, DownloadState.queued);
    kick();
  }

  Future<void> cancel(String id) async {
    await store.state(id, DownloadState.cancelled);
    if (_active == id) {
      _token?.cancel();
      _signal?.cancel();
      await idle;
    }
    final job = await store.job(id);
    if (job != null) await assets.removeDownload(job.manifest);
    await store.clean(id);
    await store.state(id, DownloadState.cancelled);
  }

  Future<void> _checkJob(DownloadJob job, CancelToken token) async {
    if (!current ||
        _suspended ||
        token.isCancelled ||
        await store.stateOf(job.id) != DownloadState.running) {
      throw const ReaderFailure(FailureKind.cancelled, 'Download interrupted.');
    }
  }

  Future<ReaderManifest> _manifest(
    String book,
    CancelToken token,
    CancellationSignal signal,
  ) async {
    final request = PageRequest(
      priority: PagePriority.download,
      onForegroundDemand: token.cancel,
    );
    await gate.acquire(signal, request);
    try {
      return await loadManifest(book, token);
    } finally {
      gate.release(request);
    }
  }

  static bool _cancelled(Object error) =>
      (error is ReaderFailure && error.kind == FailureKind.cancelled) ||
      (error is ApiFailure && error.kind == FailureKind.cancelled);

  /// Returns false when a borrowed foreground slot was reclaimed by the
  /// reader: only that page is cancelled and the caller requeues it.
  Future<bool> _downloadPage(
    DownloadJob job,
    int page,
    Map<int, DownloadAsset> parts,
    CancelToken token,
    CancellationSignal signal, {
    bool borrow = false,
  }) async {
    await _checkJob(job, token);
    final partial = store.file(job.id, page, partial: true);
    await partial.parent.create(recursive: true);
    // A borrowed transfer is preempted alone; the job keeps its other stream.
    final pageToken = borrow ? CancelToken() : token;
    final pageSignal = borrow ? CancellationController() : signal;
    var preempted = false;
    if (borrow) {
      unawaited(token.whenCancel.then((_) => pageToken.cancel()));
      unawaited(
        pageToken.whenCancel.then(
          (_) => (pageSignal as CancellationController).cancel(),
        ),
      );
    }
    final request = PageRequest(
      priority: PagePriority.download,
      borrowForegroundSlot: borrow,
      onForegroundDemand: borrow
          ? () {
              preempted = true;
              pageToken.cancel();
            }
          : token.cancel,
      maximumBytes: job.manifest.isDocument
          ? 0
          : store.pageBudget(job.manifest, page),
    );
    try {
      await gate.acquire(pageSignal, request);
    } catch (_) {
      if (preempted && !token.isCancelled) return false;
      rethrow;
    }
    try {
      // Token-to-signal propagation is asynchronous: never start a transfer
      // admitted just after its job or borrowed slot was cancelled.
      if (token.isCancelled || pageToken.isCancelled) {
        if (preempted && !token.isCancelled) return false;
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Download interrupted.',
        );
      }
      final ({String mediaType, int byteLength}) result;
      try {
        result = await transfer(
          job.manifest,
          page,
          partial,
          pageToken,
          store.pageBudget(job.manifest, page),
        );
      } catch (_) {
        if (preempted && !token.isCancelled) return false;
        rethrow;
      }
      await _checkJob(job, token);
      if (await partial.length() != result.byteLength ||
          result.byteLength > store.pageBudget(job.manifest, page) ||
          (job.manifest.pages[page].sizeBytes > 0 &&
              result.byteLength != job.manifest.pages[page].sizeBytes)) {
        throw const ReaderFailure(
          FailureKind.corruptContent,
          'Invalid downloaded length.',
        );
      }
      final inspected = await inspectDownloadAsset(
        partial,
        result.mediaType,
        maximumBytes: store.pageBudget(job.manifest, page),
      );
      final ready = store.file(job.id, page);
      await partial.rename(ready.path);
      await _checkJob(job, token);
      final asset = DownloadAsset(
        ready,
        inspected.checksum,
        result.mediaType,
        result.byteLength,
      );
      await store.record(job.id, page, asset);
      parts[page] = asset;
      progress.verified(job.id, page);
      return true;
    } finally {
      gate.release(request);
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> _run() async {
    for (final job in await store.jobs()) {
      if (!current || _suspended) return;
      if (job.state != DownloadState.queued ||
          job.retryAt > DateTime.now().millisecondsSinceEpoch) {
        continue;
      }
      _active = job.id;
      final token = CancelToken();
      final signal = CancellationController();
      _token = token;
      _signal = signal;
      token.whenCancel.then((_) => signal.cancel());
      await store.state(job.id, DownloadState.running);
      try {
        final latest = await _manifest(job.manifest.bookId, token, signal);
        if (latest.revision != job.manifest.revision) {
          throw const ReaderFailure(
            FailureKind.corruptContent,
            'Book changed. Cancel and download its new revision.',
          );
        }
        final parts = await store.parts(job.id);
        progress.begin(job.id, job.manifest.assetCount, parts.keys);
        final missing = [
          for (var page = 0; page < job.manifest.assetCount; page++)
            if (!parts.containsKey(page)) page,
        ];
        // A small fixed pool hides per-page round-trip latency. The first
        // stream uses the regular speculative slot; extra streams borrow the
        // reader's reserved slot and are preempted page-by-page on demand.
        Object? failure;
        StackTrace? failureTrace;
        Future<void> worker({required bool borrow}) async {
          while (missing.isNotEmpty && failure == null) {
            final page = missing.removeAt(0);
            try {
              if (!await _downloadPage(
                job,
                page,
                parts,
                token,
                signal,
                borrow: borrow,
              )) {
                // Reader reclaimed the borrowed slot: hand the page back and
                // continue on the job's regular stream only.
                missing.insert(0, page);
                return;
              }
            } catch (error, trace) {
              // Keep the root cause, not a sibling's induced cancellation.
              if (failure == null ||
                  (_cancelled(failure!) && !_cancelled(error))) {
                failure = error;
                failureTrace = trace;
              }
              // Siblings finish (and record) their in-flight page, then stop.
              return;
            }
          }
        }

        await Future.wait([
          for (var i = 0; i < downloadPageConcurrency; i++)
            worker(borrow: i > 0),
        ]);
        if (failure != null) {
          Error.throwWithStackTrace(failure!, failureTrace!);
        }
        final finalManifest = await _manifest(
          job.manifest.bookId,
          token,
          signal,
        );
        if (finalManifest.revision != job.manifest.revision) {
          throw const ReaderFailure(
            FailureKind.corruptContent,
            'Book changed during download.',
          );
        }
        await _checkJob(job, token);
        await store.state(job.id, DownloadState.verifying);
        await assets.installVerifiedDownload(finalManifest, parts, signal);
        if (!current || signal.isCancelled) {
          throw const ReaderFailure(
            FailureKind.cancelled,
            'Download interrupted.',
          );
        }
        await store.state(job.id, DownloadState.complete);
        await store.clean(job.id);
      } catch (error) {
        final state = await store.stateOf(job.id);
        if (state == DownloadState.running ||
            state == DownloadState.verifying) {
          final kind = error is ApiFailure
              ? error.kind
              : error is ReaderFailure
              ? error.kind
              : null;
          final retryable =
              kind == FailureKind.cancelled ||
              kind == FailureKind.offlineUnavailable ||
              kind == FailureKind.transientNetwork ||
              kind == FailureKind.serverRejected ||
              kind == FailureKind.rateLimited;
          final attempt = kind == FailureKind.cancelled
              ? job.attempt
              : job.attempt + 1;
          await store.state(
            job.id,
            retryable ? DownloadState.queued : DownloadState.failed,
            error: kind == FailureKind.cancelled
                ? null
                : error is FileSystemException
                ? 'Storage unavailable or full. Free space and retry.'
                : error is ReaderFailure
                ? error.message
                : error is ApiFailure
                ? error.message
                : 'Download failed. Retry when ready.',
            attempt: attempt,
            retryAt: retryable
                ? DateTime.now().millisecondsSinceEpoch +
                      (kind == FailureKind.cancelled
                          ? 250
                          : 1000 * (1 << attempt.clamp(0, 8)))
                : 0,
          );
        }
      } finally {
        _active = null;
        if (identical(_token, token)) _token = null;
        if (identical(_signal, signal)) _signal = null;
      }
    }
  }

  void close() {
    progress.close();
    for (final token in _enqueuing) {
      token.cancel();
    }
    _closed = true;
    _retry?.cancel();
    _token?.cancel();
    _signal?.cancel();
  }
}
