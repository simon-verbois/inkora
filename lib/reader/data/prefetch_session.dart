import 'dart:async';

import '../domain/content_key.dart';
import '../domain/page_source.dart';
import '../domain/prefetch_policy.dart';
import '../domain/reader_manifest.dart';
import '../domain/webtoon_layout.dart';
import 'encoded_page_cache.dart';
import 'tiered_page_source.dart';

final class ChapterAhead {
  const ChapterAhead(this.manifest, this.source, this.release);
  final ReaderManifest manifest;
  final PrioritizedPageSource source;
  final void Function() release;
}

/// Speculative subscribers own their cancellation, never the shared transfer.
final class PrefetchSession {
  PrefetchSession(
    this.manifest,
    this.source,
    this.policy,
    this.memory, {
    Duration Function()? now,
    this.prepareNext,
  }) {
    final watch = Stopwatch()..start();
    _now = now ?? (() => watch.elapsed);
    if (source is TieredPageSource) {
      _networkSubscription = (source as TieredPageSource).networkEvents.listen(
        (_) => _replan(),
      );
    }
  }
  final ReaderManifest manifest;
  final PrioritizedPageSource source;
  final PrefetchPolicy policy;
  final EncodedPageCache memory;
  final Future<ChapterAhead?> Function(CancellationSignal)? prepareNext;
  CancellationController? _chapterCancellation;
  late final Duration Function() _now;
  final _work = <ContentKey, _PrefetchWork>{};
  final _completed = <ContentKey>{};
  final _failed = <ContentKey, Duration>{};
  List<PrefetchDemand> demands = const [];
  int generation = 0;
  int cancelled = 0;
  int readyBeforeDemand = 0;
  int foregroundDemands = 0;
  int _current = 0;
  int _visiblePages = 1;
  WebtoonLayout? _layout;
  double _offset = 0;
  double _viewportHeight = 0;
  bool _closed = false;
  bool _suspended = false;
  bool _preparing = false;
  ChapterAhead? _next;
  Timer? _retryTimer;
  StreamSubscription<void>? _networkSubscription;
  int get pending => _work.length;
  bool get bandwidthLimited => policy.bandwidthLimited;

  void foreground(ContentKey key) {
    foregroundDemands++;
    if (memory.contains(key)) readyBeforeDemand++;
  }

  void update(
    int current, {
    WebtoonLayout? layout,
    double offset = 0,
    double viewportHeight = 0,
    int visiblePages = 1,
  }) {
    if (_closed || _suspended) return;
    final modeChanged = (_layout == null) != (layout == null);
    if (modeChanged) {
      policy.resetMotion();
      _newGeneration();
    }
    final reversed = policy.position(
      layout == null ? current.toDouble() : offset,
      _now(),
      pixels: layout != null,
    );
    if (reversed || (current - _current).abs() > 3) _newGeneration();
    _current = current;
    _visiblePages = visiblePages;
    _layout = layout;
    _offset = offset;
    _viewportHeight = viewportHeight;
    _replan();
  }

  void _newGeneration() {
    generation++;
    for (final work in _work.values) {
      work.cancellation.cancel();
      cancelled++;
    }
    _work.clear();
    _completed.clear();
    _failed.clear();
    _chapterCancellation?.cancel();
    _chapterCancellation = null;
    _next?.release();
    _next = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _replan() {
    if (_closed || _suspended) return;
    demands = policy.plan(
      manifest,
      _current,
      _now(),
      layout: _layout,
      offset: _offset,
      viewportHeight: _viewportHeight,
      visiblePages: _visiblePages,
    );
    final wanted = demands.map((d) => manifest.key(d.index)).toSet();
    for (final key in _work.keys.toList()) {
      // Current visible work stays subscribed until the image subscriber joins.
      if (key.bookId == manifest.bookId &&
          !wanted.contains(key) &&
          (key.pageIndex < _current ||
              key.pageIndex >= _current + _visiblePages)) {
        _work.remove(key)!.cancellation.cancel();
        cancelled++;
      }
    }
    _completed.removeWhere(
      (key) => key.bookId == manifest.bookId && !wanted.contains(key),
    );
    for (final demand in demands) {
      final key = manifest.key(demand.index);
      _start(
        key,
        source,
        PageRequest(
          priority: PagePriority.lookahead,
          deadline: demand.deadline,
          maximumBytes: demand.byteReservation,
        ),
      );
    }
    if (_current + _visiblePages >= manifest.pages.length - 2 &&
        policy.direction > 0 &&
        !policy.paused &&
        !policy.constrained &&
        policy.network.failures == 0) {
      _prepareChapter();
    } else if (_next != null) {
      final next = _next!;
      _next = null;
      for (final key
          in _work.keys
              .where((k) => k.bookId == next.manifest.bookId)
              .toList()) {
        _work.remove(key)!.cancellation.cancel();
        cancelled++;
      }
      next.release();
    }
  }

  void _start(ContentKey key, PrioritizedPageSource from, PageRequest request) {
    if (memory.contains(key) || _completed.contains(key)) return;
    final existing = _work[key];
    if (existing != null) {
      existing.request.deadline = request.deadline;
      return;
    }
    if (_failed[key] != null && _now() < _failed[key]!) return;
    final work = _PrefetchWork(request);
    _work[key] = work;
    final ownedGeneration = generation;
    from
        .readAhead(key, cancellation: work.cancellation, request: request)
        .then(
          (page) {
            if (!_closed &&
                !work.cancellation.isCancelled &&
                generation == ownedGeneration) {
              _completed.add(key);
            }
          },
          onError: (Object _) {
            if (!_closed &&
                !work.cancellation.isCancelled &&
                generation == ownedGeneration) {
              _failed[key] = _now() + const Duration(seconds: 2);
              _retryTimer ??= Timer(const Duration(seconds: 2), () {
                _retryTimer = null;
                _replan();
              });
            }
          },
        )
        .whenComplete(() {
          if (identical(_work[key], work)) _work.remove(key);
        });
  }

  void _prepareChapter() {
    if (prepareNext == null || _preparing || _next != null) return;
    _preparing = true;
    final ownedGeneration = generation;
    final chapterCancellation = CancellationController();
    _chapterCancellation = chapterCancellation;
    prepareNext!(chapterCancellation)
        .then((chapter) {
          if (chapter == null) return;
          if (_closed ||
              chapterCancellation.isCancelled ||
              _suspended ||
              generation != ownedGeneration ||
              policy.direction < 0 ||
              _current + _visiblePages < manifest.pages.length - 2) {
            chapter.release();
            return;
          }
          if (chapter.manifest.accountId != manifest.accountId ||
              chapter.manifest.bookId == manifest.bookId) {
            chapter.release();
            return;
          }
          _next = chapter;
          final size = chapter.manifest.pages.first.sizeBytes;
          final reservation = size == 0
              ? 32 * 1024 * 1024
              : (size + size ~/ 4 + 65536).clamp(1, 32 * 1024 * 1024);
          if (reservation > policy.encodedBudget) return;
          _start(
            chapter.manifest.key(0),
            chapter.source,
            PageRequest(
              priority: PagePriority.chapter,
              deadline: _now() + const Duration(seconds: 4),
              maximumBytes: reservation,
            ),
          );
        }, onError: (Object _) {})
        .whenComplete(() {
          _preparing = false;
        });
  }

  void configureNetwork({required bool constrained, required bool paused}) {
    if (policy.constrained == constrained && policy.paused == paused) return;
    policy.constrained = constrained;
    policy.paused = paused;
    _newGeneration();
    _replan();
  }

  void suspend(bool value) {
    if (_suspended == value) return;
    _suspended = value;
    if (value) {
      _newGeneration();
    } else {
      _replan();
    }
  }

  void close() {
    unawaited(_networkSubscription?.cancel());
    _networkSubscription = null;
    _closed = true;
    _newGeneration();
  }
}

final class _PrefetchWork {
  _PrefetchWork(this.request);
  final PageRequest request;
  final cancellation = CancellationController();
}
