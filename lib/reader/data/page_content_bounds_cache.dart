import 'dart:async';
import 'dart:collection';

import '../domain/content_key.dart';
import '../domain/page_content_bounds.dart';
import '../domain/page_source.dart';

/// Account/revision-keyed, bounded metadata LRU and one thumbnail analysis at a
/// time. Jobs borrow existing acquired buffers; no transport/cache read occurs.
final class PageContentBoundsCache {
  PageContentBoundsCache(
    this.analyze, {
    this.maximumEntries = 512,
    this.maximumQueued = 6,
    this.maximumQueuedBytes = 32 * 1024 * 1024,
  });
  final Future<PageContentBounds> Function(EncodedPage) analyze;
  final int maximumEntries, maximumQueued, maximumQueuedBytes;
  final _values = <ContentKey, PageContentBounds>{};
  final _jobs = <ContentKey, _BoundsJob>{};
  final _queue = ListQueue<_BoundsJob>();
  var _queuedBytes = 0, _generation = 0;
  bool _active = false, _paused = false;
  int _resumeEpoch = 0;
  int get resumeEpoch => _resumeEpoch;
  int get length => _values.length;
  int get queuedBytes => _queuedBytes;
  PageContentBounds? peek(ContentKey key) => _values[key];

  Future<PageContentBounds> request(
    EncodedPage page, {
    required bool visible,
    required CancellationSignal cancellation,
  }) {
    final cached = _values.remove(page.key);
    if (cached != null) {
      _values[page.key] = cached;
      return Future.value(cached);
    }
    if (_paused || cancellation.isCancelled) {
      return Future.value(PageContentBounds.full);
    }
    final existing = _jobs[page.key];
    if (existing != null) {
      existing.consumers.add(cancellation);
      existing.visible |= visible;
      if (visible && _queue.remove(existing)) _queue.addFirst(existing);
      return existing.result.future;
    }
    while (visible &&
        (_queue.length >= maximumQueued ||
            _queuedBytes + page.bytes.length > maximumQueuedBytes)) {
      final speculative = _queue.where((job) => !job.visible).lastOrNull;
      if (speculative == null) break;
      _cancelQueued((key) => key == speculative.page.key);
    }
    if (_queue.length >= maximumQueued ||
        _queuedBytes + page.bytes.length > maximumQueuedBytes) {
      return Future.value(PageContentBounds.full);
    }
    final job = _BoundsJob(page, cancellation, _generation, visible);
    _jobs[page.key] = job;
    _queuedBytes += page.bytes.length;
    visible ? _queue.addFirst(job) : _queue.addLast(job);
    _drain();
    return job.result.future;
  }

  void _drain() {
    if (_active || _paused || _queue.isEmpty) return;
    final job = _queue.removeFirst();
    _queuedBytes -= job.page.bytes.length;
    if (job.consumers.every((signal) => signal.isCancelled)) {
      _jobs.remove(job.page.key);
      job.result.complete(PageContentBounds.full);
      _drain();
      return;
    }
    _active = true;
    unawaited(_run(job));
  }

  Future<void> _run(_BoundsJob job) async {
    var bounds = PageContentBounds.full;
    try {
      bounds = await analyze(job.page);
      if (!job.invalidated &&
          job.generation == _generation &&
          !_paused &&
          job.consumers.any((signal) => !signal.isCancelled)) {
        _values[job.page.key] = bounds;
        while (_values.length > maximumEntries) {
          _values.remove(_values.keys.first);
        }
      }
    } catch (_) {
      // Detection is optional: corrupt/unsupported thumbnails keep normal fit.
    } finally {
      if (identical(_jobs[job.page.key], job)) _jobs.remove(job.page.key);
      job.result.complete(
        job.invalidated || job.generation != _generation
            ? PageContentBounds.full
            : bounds,
      );
      _active = false;
      _drain();
    }
  }

  void invalidate(ContentKey key) {
    _values.remove(key);
    _cancelQueued((candidate) => candidate == key);
    _jobs.remove(key);
  }

  void clearAccount(String account) {
    _values.removeWhere((key, _) => key.accountId == account);
    _cancelQueued((key) => key.accountId == account);
  }

  void retainRevision(String account, String book, String revision) {
    bool obsolete(ContentKey key) =>
        key.accountId == account &&
        key.bookId == book &&
        key.revision != revision;
    _values.removeWhere((key, _) => obsolete(key));
    _cancelQueued(obsolete);
  }

  void _cancelQueued(bool Function(ContentKey) remove) {
    for (final job
        in _jobs.values.where((job) => remove(job.page.key)).toList()) {
      job.invalidated = true;
      _jobs.remove(job.page.key);
    }
    for (final job in _queue.where((job) => remove(job.page.key)).toList()) {
      _queue.remove(job);
      _queuedBytes -= job.page.bytes.length;
      _jobs.remove(job.page.key);
      job.result.complete(PageContentBounds.full);
    }
  }

  void clear() {
    _generation++;
    _values.clear();
    _cancelQueued((_) => true);
    // Running native thumbnail decode finishes, but cannot refill the LRU.
    _jobs.clear();
  }

  void pause(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (paused) {
      // Completed rectangles are tiny and remain useful on resume. Drop only
      // unfinished work and borrowed encoded buffers while hidden.
      _generation++;
      _cancelQueued((_) => true);
      _jobs.clear();
    } else {
      _resumeEpoch++;
      _drain();
    }
  }
}

final class _BoundsJob {
  _BoundsJob(
    this.page,
    CancellationSignal consumer,
    this.generation,
    this.visible,
  ) : consumers = {consumer};
  final EncodedPage page;
  final int generation;
  bool visible;
  bool invalidated = false;
  final Set<CancellationSignal> consumers;
  final result = Completer<PageContentBounds>();
}
