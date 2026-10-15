import 'dart:async';

import '../../core/errors/failure_kind.dart';
import '../domain/content_key.dart';
import '../domain/reader_trace.dart';
import '../domain/page_source.dart';
import '../domain/reader_manifest.dart';
import 'reader_asset_store.dart';
import 'encoded_page_cache.dart';
import 'page_network_gate.dart';
export 'page_network_gate.dart';

final class TieredPageSource implements PrioritizedPageSource {
  TieredPageSource(
    this.manifest,
    this.assets,
    this.remote,
    this.gate, {
    EncodedPageCache? memory,
  }) : memory = memory ?? EncodedPageCache(maximumBytes: 0);
  final EncodedPageCache memory;
  final tierHits = <String, int>{};
  void _hit(String tier) {
    tierHits[tier] = (tierHits[tier] ?? 0) + 1;
  }

  final ReaderManifest manifest;
  final ReaderAssetStore assets;
  final PageSource remote;
  final PageNetworkGate gate;
  final _flights = <ContentKey, _Flight>{};
  final _networkEvents = StreamController<void>.broadcast();
  Stream<void> get networkEvents => _networkEvents.stream;
  void _networkChanged() {
    if (!_networkEvents.isClosed) _networkEvents.add(null);
  }

  var _closed = false;
  final _invalidDownloads = <ContentKey>{};

  @override
  Future<void> invalidate(ContentKey key) async {
    manifest.checkKey(key);
    _invalidDownloads.add(key);
    memory.remove(key);
    await assets.invalidateCache(key);
  }

  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) {
    final shared = _flights[key]?.request;
    final result = _read(key, cancellation, PageRequest());
    if (shared == null || shared.maximumBytes == maximumEncodedPageBytes) {
      return result;
    }
    // Metadata may underestimate a speculative image. Visible subscribers get
    // one full-budget retry; speculation must never impose its smaller cap.
    return result.onError<ReaderFailure>((error, trace) {
      if (!_closed &&
          !cancellation.isCancelled &&
          (error.kind == FailureKind.corruptContent ||
              error.kind == FailureKind.cancelled)) {
        return _read(key, cancellation, PageRequest());
      }
      Error.throwWithStackTrace(error, trace);
    });
  }

  @override
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  }) => _read(key, cancellation, request);

  Future<EncodedPage> _read(
    ContentKey key,
    CancellationSignal cancellation,
    PageRequest request,
  ) {
    ReaderTrace.sink?.call('acquire', key.pageIndex, {
      'priority': request.priority.name,
      'maximumBytes': request.maximumBytes,
      'request': identityHashCode(request),
    });
    manifest.checkKey(key);
    if (_closed || cancellation.isCancelled) {
      return Future.error(
        const ReaderFailure(FailureKind.cancelled, 'Page loading cancelled.'),
      );
    }
    var flight = _flights[key];
    if (flight == null || flight.cancellation.isCancelled) {
      flight = _Flight(request);
      _flights[key] = flight;
      final owned = flight;
      flight.result = _resolve(key, flight.cancellation, flight.request)
          .whenComplete(() {
            owned.finished = true;
            if (identical(_flights[key], owned)) _flights.remove(key);
          });
    }
    if (request.priority == PagePriority.visible) gate.promote(flight.request);
    flight.subscribers++;
    final subscriber = _Subscriber(flight);
    final result = subscriber.delivery!.future;
    flight.result.then(subscriber.succeed, onError: subscriber.fail);
    cancellation.whenCancelled.then(
      (_) => subscriber.fail(
        const ReaderFailure(FailureKind.cancelled, 'Page loading cancelled.'),
        StackTrace.empty,
      ),
    );
    return result;
  }

  Future<EncodedPage> _resolve(
    ContentKey key,
    CancellationSignal cancellation,
    PageRequest request,
  ) async {
    ReaderFailure? localFailure;
    if (ReaderTrace.sink != null) {
      cancellation.whenCancelled.then(
        (_) => ReaderTrace.sink?.call('flight-cancel', key.pageIndex, {}),
      );
    }
    for (final tier in ['download', 'cache']) {
      if (tier == 'download' && _invalidDownloads.contains(key)) continue;
      try {
        if (tier == 'cache') {
          final cached = memory.get(key);
          if (cached != null) {
            ReaderTrace.sink?.call('bytes', key.pageIndex, {
              'tier': 'memory',
              'bytes': cached.bytes.length,
            });
            _hit('memory');
            return cached;
          }
        }
        final page = await assets.read(
          key,
          tier,
          cancellation,
          maximumBytes: request.maximumBytes,
        );
        if (cancellation.isCancelled) {
          throw const ReaderFailure(
            FailureKind.cancelled,
            'Page loading cancelled.',
          );
        }
        if (page != null) {
          ReaderTrace.sink?.call('bytes', key.pageIndex, {
            'tier': tier,
            'bytes': page.bytes.length,
          });
          _hit(tier);
          memory.put(page);
          return page;
        }
      } on ReaderFailure catch (error) {
        if (error.kind == FailureKind.cancelled) rethrow;
        localFailure = error;
      }
    }
    ReaderTrace.sink?.call('admission-wait', key.pageIndex, {
      'priority': request.priority.name,
    });
    await gate.acquire(cancellation, request);
    ReaderTrace.sink?.call('admitted', key.pageIndex, {
      'priority': request.priority.name,
    });
    try {
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Page loading cancelled.',
        );
      }
      final page = remote is BudgetedPageSource
          ? await (remote as BudgetedPageSource).readWithinBudget(
              key,
              cancellation: cancellation,
              maximumBytes: request.maximumBytes,
            )
          : await remote.read(key, cancellation: cancellation);
      if (page.key != key) {
        throw const ReaderFailure(
          FailureKind.corruptContent,
          'Loaded page identity does not match.',
        );
      }
      validateRaster(page.bytes, page.mediaType);
      if (page.bytes.length > request.maximumBytes) {
        throw const ReaderFailure(
          FailureKind.corruptContent,
          'Page exceeds its reserved byte budget.',
        );
      }
      if (page.networkSample != null) {
        gate.estimate.observe(page.networkSample!);
      }
      if (request.priority == PagePriority.visible) {
        gate.estimate.recoverForeground();
      }
      ReaderTrace.sink?.call('network-bytes', key.pageIndex, {
        'bytes': page.bytes.length,
      });
      _hit('network');
      _networkChanged();
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Page loading cancelled.',
        );
      }
      // Cache failures must not prevent presentation of valid acquired bytes.
      try {
        await assets.cache(page);
      } catch (_) {
        /* Disk full/cache unavailable. */
      }
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Page loading cancelled.',
        );
      }
      memory.put(page);
      ReaderTrace.sink?.call('bytes', key.pageIndex, {
        'tier': 'network',
        'bytes': page.bytes.length,
      });
      return page;
    } on ReaderFailure catch (error) {
      if (error.kind == FailureKind.transientNetwork ||
          error.kind == FailureKind.rateLimited ||
          error.kind == FailureKind.serverRejected ||
          error.kind == FailureKind.offlineUnavailable) {
        gate.estimate.failed();
        _networkChanged();
      }
      if (localFailure != null &&
          error.kind == FailureKind.offlineUnavailable) {
        throw localFailure;
      }
      rethrow;
    } finally {
      gate.release(request);
    }
  }

  void close() {
    _closed = true;
    unawaited(_networkEvents.close());
    for (final flight in _flights.values) {
      flight.cancellation.cancel();
    }
    _flights.clear();
  }
}

final class _Flight {
  _Flight(this.request);
  final PageRequest request;
  final cancellation = CancellationController();
  late Future<EncodedPage> result;
  var subscribers = 0;
  var finished = false;
}

/// Clears heavy references when delivered; long-lived cancellation futures
/// otherwise retain already-completed page buffers through their callbacks.
final class _Subscriber {
  _Subscriber(this.flight);
  _Flight? flight;
  Completer<EncodedPage>? delivery = Completer<EncodedPage>();
  void _release() {
    final owned = flight;
    flight = null;
    if (owned == null) return;
    owned.subscribers--;
    if (owned.subscribers == 0 && !owned.finished) owned.cancellation.cancel();
  }

  void succeed(EncodedPage page) {
    final receiver = delivery;
    delivery = null;
    if (receiver == null) return;
    _release();
    receiver.complete(page);
  }

  void fail(Object error, StackTrace trace) {
    final receiver = delivery;
    delivery = null;
    if (receiver == null) return;
    _release();
    receiver.completeError(error, trace);
  }
}
