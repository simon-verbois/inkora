import 'dart:async';

import '../../core/errors/failure_kind.dart';
import '../domain/page_source.dart';
import '../domain/content_key.dart';
import '../domain/reader_trace.dart';
import '../domain/prefetch_policy.dart';
import '../domain/reader_manifest.dart';

enum PagePriority { visible, lookahead, chapter, download }

final class PageRequest {
  PageRequest({
    this.priority = PagePriority.visible,
    this.deadline = Duration.zero,
    this.maximumBytes = 32 * 1024 * 1024,
    this.onForegroundDemand,
    this.borrowForegroundSlot = false,
  });
  PagePriority priority;
  Duration deadline;
  final int maximumBytes;
  final void Function()? onForegroundDemand;
  final bool borrowForegroundSlot;
}

/// One reserved request slot and 32 MiB of byte capacity for visible demand.
/// Active work drains on a limit decrease; queued priorities change in place.
final class PageNetworkGate {
  PageNetworkGate({int limit = 2, ReaderNetworkEstimate? estimate})
    : estimate = estimate ?? ReaderNetworkEstimate() {
    if (limit < 1 || limit > 8) throw ArgumentError('Invalid page concurrency');
    this.estimate.concurrency = limit;
  }
  final ReaderNetworkEstimate estimate;
  int get limit => estimate.concurrency;
  int active = 0;
  int _speculative = 0;
  int _speculativeBytes = 0;
  final _waiting = <_Admission>[];
  final _clock = Stopwatch()..start();
  final foregroundQueueMicros = <int>[];
  int peakActive = 0;
  final _leases = <PageRequest, bool>{};
  int get waiting => _waiting.length;
  int get speculativeBytes => _speculativeBytes;
  static bool _canBorrow(PageRequest request) =>
      request.borrowForegroundSlot &&
      request.priority == PagePriority.download &&
      request.onForegroundDemand != null;

  Future<void> acquire(
    CancellationSignal cancellation, [
    PageRequest? request,
  ]) {
    request ??= PageRequest();
    ReaderTrace.sink?.call('gate-queued', null, {
      'request': identityHashCode(request),
      'priority': request.priority.name,
      'active': active,
      'limit': limit,
      'speculativeBytes': _speculativeBytes,
    });
    if (cancellation.isCancelled) return Future.error(_cancelled);
    if (request.priority == PagePriority.visible && active >= limit) {
      // Borrowed leases (artwork, extra download streams) are reclaimed
      // first; a regular download stream is preempted only when nothing
      // borrowed the reserved slot (single-slot gates).
      final downloads = [
        for (final lease in _leases.keys)
          if (lease.priority == PagePriority.download &&
              lease.onForegroundDemand != null)
            lease,
      ];
      final borrowed = downloads.where((lease) => lease.borrowForegroundSlot);
      for (final lease in (borrowed.isEmpty ? downloads : borrowed).toList()) {
        lease.onForegroundDemand!.call();
      }
    }
    final admission = _Admission(cancellation, request, _clock.elapsed);
    _waiting.add(admission);
    cancellation.whenCancelled.then((_) {
      if (_waiting.remove(admission)) {
        ReaderTrace.sink?.call('gate-cancel', null, {
          'request': identityHashCode(admission.request),
        });
        admission.ready.completeError(_cancelled);
      }
      pump();
    });
    pump();
    return admission.ready.future;
  }

  static const _cancelled = ReaderFailure(
    FailureKind.cancelled,
    'Page loading cancelled.',
  );
  void promote(PageRequest request) {
    ReaderTrace.sink?.call('gate-promote', null, {
      'request': identityHashCode(request),
      'from': request.priority.name,
    });
    request.priority = PagePriority.visible;
    request.deadline = Duration.zero;
    // A promoted active transfer consumes foreground capacity now.
    if (_leases[request] == true) {
      _leases[request] = false;
      _speculative--;
      _speculativeBytes -= request.maximumBytes;
    }
    pump();
  }

  void pump() {
    _waiting.sort((a, b) {
      final priority = a.request.priority.index.compareTo(
        b.request.priority.index,
      );
      return priority != 0
          ? priority
          : a.request.deadline.compareTo(b.request.deadline);
    });
    while (active < limit && _waiting.isNotEmpty) {
      final next = _waiting.first;
      final spec = next.request.priority != PagePriority.visible;
      final borrow = _canBorrow(next.request);
      // A borrowed lease occupies otherwise reserved foreground capacity. It
      // must not consume the ordinary speculative allowance if it starts first.
      // Derive this from the existing leases (at most eight), so promotion and
      // release cannot leave a second admission counter out of sync.
      final occupied = borrow
          ? _speculative
          : _leases.entries
                .where((lease) => lease.value && !_canBorrow(lease.key))
                .length;
      if (spec &&
          (occupied >=
                  (borrow
                      ? limit
                      : limit > 1
                      ? limit - 1
                      : (next.request.priority == PagePriority.download
                            ? 1
                            : 0)) ||
              _speculativeBytes + next.request.maximumBytes >
                  32 * 1024 * 1024)) {
        break;
      }
      _waiting.removeAt(0);
      if (next.cancellation.isCancelled) {
        next.ready.completeError(_cancelled);
        continue;
      }
      active++;
      if (active > peakActive) peakActive = active;
      if (!spec) {
        final delay = (_clock.elapsed - next.enqueued).inMicroseconds;
        foregroundQueueMicros.add(delay);
        if (foregroundQueueMicros.length > 1024) {
          foregroundQueueMicros.removeAt(0);
        }
        estimate.foregroundQueueSeconds = delay / 1e6;
      }
      if (spec) {
        _speculative++;
        _speculativeBytes += next.request.maximumBytes;
      }
      ReaderTrace.sink?.call('gate-admitted', null, {
        'request': identityHashCode(next.request),
        'priority': next.request.priority.name,
        'active': active,
        'limit': limit,
        'speculativeBytes': _speculativeBytes,
      });
      _leases[next.request] = spec;
      next.ready.complete();
    }
  }

  void release([PageRequest? request]) {
    request ??= _leases.keys.first;
    final spec = _leases.remove(request);
    if (spec == null) throw StateError('Unowned network admission');
    active--;
    if (spec) {
      _speculative--;
      _speculativeBytes -= request.maximumBytes;
    }
    pump();
  }
}

final class _Admission {
  _Admission(this.cancellation, this.request, this.enqueued);
  final Duration enqueued;
  final CancellationSignal cancellation;
  final PageRequest request;
  final ready = Completer<void>();
}

abstract interface class PrioritizedPageSource
    implements InvalidatablePageSource {
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  });
}

abstract interface class BudgetedPageSource implements PageSource {
  Future<EncodedPage> readWithinBudget(
    ContentKey key, {
    required CancellationSignal cancellation,
    required int maximumBytes,
  });
}
