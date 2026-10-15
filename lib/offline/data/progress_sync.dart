import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../core/errors/failure_kind.dart';
import '../../core/network/komga/api_failure.dart';
import '../../core/network/komga/komga_client.dart';
import '../../core/network/komga/komga_models.dart';
import '../../reader/data/komga_reader_remote.dart';
import '../../reader/data/page_network_gate.dart';
import '../../reader/domain/page_source.dart';
import '../../reader/domain/ebook_locator.dart';
import '../domain/progress.dart';
import 'progress_store.dart';

import 'package:dio/dio.dart';

abstract interface class ProgressRemote {
  Future<ProgressSnapshot> read(
    String book, {
    CancellationSignal? cancellation,
  });
  Future<void> write(
    String book,
    ProgressSnapshot target, {
    CancellationSignal? cancellation,
  });
}

final class KomgaProgressRemote implements ProgressRemote {
  KomgaProgressRemote(this.client, this.accountId, {int Function()? now})
    : now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final KomgaClient client;
  final String accountId;
  final int Function() now;

  /// Each replay reads progress before and after a write. The revision needs
  /// the full page list, so it is memoized per book against the book-level
  /// file fingerprint; any file/size/page-count/media change or expiry falls
  /// back to the full manifest load.
  final _revisions =
      <
        String,
        ({
          String fingerprint,
          String revision,
          int pages,
          int at,
          bool epub,
          List<Map<String, dynamic>> positions,
        })
      >{};
  void trimMemory() => _revisions.clear();

  static const _revisionLifetime = 10 * 60 * 1000;

  static String _fingerprint(Map<String, dynamic> book) {
    final media = book['media'];
    return jsonEncode([
      book['fileHash'],
      book['fileLastModified'],
      book['sizeBytes'],
      book['deleted'],
      if (media is Map) ...[
        media['status'],
        media['mediaProfile'],
        media['pagesCount'],
      ],
    ]);
  }

  @override
  Future<ProgressSnapshot> read(
    String book, {
    CancellationSignal? cancellation,
  }) async {
    final token = CancelToken();
    cancellation?.whenCancelled.then((_) => token.cancel());
    if (cancellation?.isCancelled ?? false) token.cancel();
    var cached = _revisions[book];
    if (cached != null && now() - cached.at >= _revisionLifetime) {
      _revisions.remove(book);
      cached = null;
    }
    late Map<String, dynamic> json;
    late String revision;
    late int pageCount;
    if (cached != null) {
      json = await client.bookDetails(book, jsonObject, cancelToken: token);
      if (requiredString(json, 'id') == book &&
          _fingerprint(json) == cached.fingerprint) {
        revision = cached.revision;
        pageCount = cached.pages;
      } else {
        _revisions.remove(book);
      }
    }
    if (!_revisions.containsKey(book)) {
      final manifest = await KomgaReaderRemote.loadManifest(
        client,
        accountId,
        book,
        token,
        onBook: (value) => json = value,
      );
      revision = manifest.revision;
      pageCount = manifest.pages.length;
      while (_revisions.isNotEmpty &&
          (_revisions.length >= 64 ||
              _revisions.values.fold<int>(
                    manifest.positions.length,
                    (sum, entry) => sum + entry.positions.length,
                  ) >
                  20000)) {
        _revisions.remove(_revisions.keys.first);
      }
      _revisions[book] = (
        fingerprint: _fingerprint(json),
        revision: revision,
        pages: pageCount,
        at: now(),
        epub: manifest.documentType == 'application/epub+zip',
        positions: manifest.positions,
      );
    }
    final content = _revisions[book]!;
    if (content.epub) {
      final progression = await client.ebookProgression(
        book,
        cancelToken: token,
      );
      if (progression == null) return ProgressSnapshot(revision: revision);
      final raw = jsonObject(progression['locator']);
      if ((raw['href'] as String? ?? '').isEmpty) {
        return ProgressSnapshot(revision: revision);
      }
      final locator = EbookLocator(raw);
      return ProgressSnapshot(
        revision: revision,
        pageIndex: locator.positionIn(content.positions),
        completed: locator.total >= 0.99,
        version: progression['modified'] as String?,
        documentLocator: locator.encode(),
      );
    }
    final progress = json['readProgress'];
    if (progress == null) return ProgressSnapshot(revision: revision);
    final dto = jsonObject(progress);
    if (requiredInt(dto, 'page', minimum: 1) > pageCount) {
      throw const FormatException('Progress exceeds current revision');
    }
    return ProgressSnapshot(
      revision: revision,
      pageIndex: requiredInt(dto, 'page', minimum: 1) - 1,
      completed: requiredBool(dto, 'completed'),
      version: dto['lastModified'] as String?,
    );
  }

  @override
  Future<void> write(
    String book,
    ProgressSnapshot target, {
    CancellationSignal? cancellation,
  }) {
    final token = CancelToken();
    cancellation?.whenCancelled.then((_) => token.cancel());
    if (cancellation?.isCancelled ?? false) token.cancel();
    if (target.documentLocator != null) {
      return client.updateEbookProgression(
        book,
        target.completed && (_revisions[book]?.positions.isNotEmpty ?? false)
            ? _revisions[book]!.positions.last
            : EbookLocator.decode(target.documentLocator!).value,
        cancelToken: token,
        modifiedAfter: target.version,
      );
    }
    return target.pageIndex == null && !target.completed
        ? client.resetProgress(book, cancelToken: token)
        : client.updateProgress(
            book,
            pageIndex: target.pageIndex,
            completed: target.completed,
            cancelToken: token,
          );
  }
}

/// A single account worker preserves book ordering; a sent sequence is never
/// acknowledged through a range delete, even if a newer local event arrives.
final class ProgressSync {
  ProgressSync(
    this.store,
    this.remote,
    this.gate, {
    required this.isCurrent,
    int Function()? now,
    double Function()? jitter,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       jitter = jitter ?? Random().nextDouble;
  final ProgressStore store;
  final ProgressRemote remote;
  final PageNetworkGate gate;
  final bool Function() isCurrent;
  final int Function() now;
  final double Function() jitter;
  Future<void>? _work;
  bool _closed = false, _paused = false, authenticationExpired = false;
  CancellationController? _activeSignal;
  bool get paused => _paused;
  set paused(bool value) {
    _paused = value;
    if (value) _activeSignal?.cancel();
  }

  Future<void> get idle => _work ?? Future.value();
  bool get current => !_closed && isCurrent();
  Future<void> replay() {
    if (!current || paused || authenticationExpired) return Future.value();
    return _work ??= _run().whenComplete(() => _work = null);
  }

  Future<void> _run() async {
    final blocked = <String>{};
    for (final queued in await store.pending()) {
      final event = await store.intent(queued.bookId, queued.sequence);
      if (event == null) continue;
      if (!current || paused || authenticationExpired) return;
      if (blocked.contains(event.bookId)) continue;
      if (event.state == 'conflict' || event.retryAt > now()) {
        blocked.add(event.bookId);
        continue;
      }
      final signal = CancellationController();
      _activeSignal = signal;
      final request = PageRequest(
        priority: PagePriority.download,
        maximumBytes: 0,
        onForegroundDemand: signal.cancel,
      );
      var admitted = false;
      try {
        await gate.acquire(signal, request);
        admitted = true;
        if (!current) return;
        await store.state(event, 'sending');
        final observed = await remote.read(event.bookId, cancellation: signal);
        if (!current) return;
        if (observed.revision != event.revision) {
          await store.state(event, 'conflict', remote: observed);
          blocked.add(event.bookId);
          continue;
        }
        final explicit =
            event.operation == ProgressOperation.rewind ||
            event.operation == ProgressOperation.markUnread;
        final target = switch (event.operation) {
          ProgressOperation.markUnread => ProgressSnapshot(
            revision: event.revision,
          ),
          ProgressOperation.rewind => ProgressSnapshot(
            revision: event.revision,
            pageIndex: event.pageIndex,
            version: observed.version,
            documentLocator: event.documentLocator,
            completed: (event.documentLocator == null
                ? event.pageIndex == event.pageCount - 1
                : EbookLocator.decode(event.documentLocator!).total >= 0.99),
          ),
          ProgressOperation.complete => ProgressSnapshot(
            revision: event.revision,
            pageIndex: max(event.pageIndex, observed.pageIndex ?? 0),
            version: observed.version,
            documentLocator: event.pageIndex >= (observed.pageIndex ?? 0)
                ? event.documentLocator
                : observed.documentLocator,
            completed: true,
          ),
          ProgressOperation.advance => ProgressSnapshot(
            revision: event.revision,
            pageIndex: max(event.pageIndex, observed.pageIndex ?? 0),
            version: observed.version,
            documentLocator: event.pageIndex >= (observed.pageIndex ?? 0)
                ? event.documentLocator
                : observed.documentLocator,
            completed:
                observed.completed ||
                (event.documentLocator == null
                    ? event.pageIndex == event.pageCount - 1
                    : EbookLocator.decode(event.documentLocator!).total >=
                          0.99),
          ),
        };
        bool satisfied(ProgressSnapshot value) => explicit
            ? value.sameState(target)
            : value.revision == target.revision &&
                  (value.completed ||
                      ((value.pageIndex ?? -1) >= (target.pageIndex ?? 0) &&
                          !target.completed &&
                          (target.documentLocator == null ||
                              (value.pageIndex ?? -1) >
                                  (target.pageIndex ?? 0) ||
                              value.preciseProgress + 0.000001 >=
                                  target.preciseProgress)));
        if (satisfied(observed)) {
          await store.acknowledge(event, observed);
          continue;
        }
        if (explicit &&
            (event.baseline == null ||
                !observed.sameVersion(event.baseline!))) {
          await store.state(event, 'conflict', remote: observed);
          blocked.add(event.bookId);
          continue;
        }
        Object? writeError;
        try {
          await remote.write(event.bookId, target, cancellation: signal);
        } catch (error) {
          writeError = error;
        }
        if (!current) return;
        // Always read back, including a timeout whose PATCH may have committed.
        final after = await remote.read(event.bookId, cancellation: signal);
        if (!current) return;
        if (satisfied(after)) {
          await store.acknowledge(
            event,
            after,
            advanceFollowingBaseline:
                event.baseline != null &&
                observed.sameVersion(event.baseline!) &&
                after.sameState(target),
          );
        } else if (writeError != null) {
          throw writeError;
        } else {
          await store.state(event, 'conflict', remote: after);
          blocked.add(event.bookId);
        }
      } catch (error) {
        if (!current) return;
        if (error is ApiFailure && error.kind == FailureKind.authentication) {
          authenticationExpired = true;
        }
        final attempt = event.attempt + 1;
        final delay =
            (1000 * (1 << attempt.clamp(0, 8)) * (0.8 + jitter() * 0.4))
                .round();
        await store.state(
          event,
          'queued',
          attempt: attempt,
          retryAt: now() + delay,
        );
        blocked.add(event.bookId);
      } finally {
        if (admitted) gate.release(request);
        signal.cancel();
        if (identical(_activeSignal, signal)) _activeSignal = null;
      }
    }
  }

  void close() {
    _closed = true;
    _activeSignal?.cancel();
  }
}
