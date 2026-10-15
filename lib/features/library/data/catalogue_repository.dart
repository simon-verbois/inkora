import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/errors/failure_kind.dart';
import '../../../core/network/komga/api_failure.dart';
import '../domain/catalogue.dart';
import 'catalogue_store.dart';

final class CatalogueRepository {
  CatalogueRepository(
    this.store,
    this.remote, {
    bool Function()? isCurrent,
    DateTime Function()? now,
  }) : _isCurrent = isCurrent ?? (() => true),
       _now = now ?? DateTime.now;
  final CatalogueStore store;
  final CatalogueRemote remote;
  final bool Function() _isCurrent;
  final DateTime Function() _now;
  final _status = StreamController<CatalogueRefreshState>.broadcast(sync: true);
  CatalogueRefreshState _state = const CatalogueRefreshState();
  bool _closed = false;
  Future<void>? _refresh;

  Stream<CatalogueRefreshState> get status => Stream.multi((controller) {
    final subscription = _status.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.add(_state);
    controller.onCancel = subscription.cancel;
  });

  bool get _canCommit => !_closed && _isCurrent();

  void _set(CatalogueRefreshState state) {
    _state = state;
    if (!_closed) _status.add(state);
  }

  Future<void> refreshIfStale() async {
    try {
      final snapshot = await store.snapshot();
      if (!_canCommit) return;
      if (snapshot == null ||
          await store.needsMediaRefresh() ||
          _now().difference(snapshot.updatedAt) >=
              const Duration(minutes: 15)) {
        await refresh();
      }
    } catch (_) {
      if (_canCommit) {
        _set(
          const CatalogueRefreshState(
            message: 'Unable to open the local catalogue. Please retry.',
          ),
        );
      }
    }
  }

  /// All catalogue kinds share one generation: failed/partial results never publish.
  /// A library refresh also refreshes cross-library memberships consistently.
  Future<void> refresh() {
    if (!_canCommit) return Future.value();
    return _refresh ??= _runRefresh().whenComplete(() => _refresh = null);
  }

  Future<void> _runRefresh() async {
    final generation = base64Url.encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    _set(const CatalogueRefreshState(busy: true));
    try {
      await store.cleanAbandoned();
      for (final kind in CatalogueKind.values) {
        await _refreshKind(kind, generation);
      }
      if (!_canCommit) {
        throw const ApiFailure(FailureKind.cancelled, 'Refresh cancelled.');
      }
      await store.publish(generation, _now(), () => _canCommit);
      _set(const CatalogueRefreshState());
    } catch (error) {
      try {
        await store.discard(generation);
      } catch (_) {
        /* Storage may already be closing after account disposal. */
      }
      if (!_canCommit) return;
      _set(
        CatalogueRefreshState(
          message: switch (error) {
            ApiFailure failure => failure.message,
            _ => 'Unable to refresh the local catalogue. Please retry.',
          },
        ),
      );
    }
  }

  /// Pipelined: page n+1 downloads while page n is validated and staged, so
  /// a refresh costs about max(network, staging) per page instead of the sum.
  /// At most one page is prefetched; staging order stays sequential.
  Future<void> _refreshKind(CatalogueKind kind, String generation) async {
    Future<RemoteCataloguePage>? next;
    try {
      var page = 0;
      int? total;
      int? totalPages;
      var received = 0;
      final seen = <String>{};
      while (true) {
        if (!_canCommit) {
          throw const ApiFailure(FailureKind.cancelled, 'Refresh cancelled.');
        }
        final result = await (next ?? remote.fetch(kind, page));
        next = null;
        if (!_canCommit) {
          throw const ApiFailure(FailureKind.cancelled, 'Refresh cancelled.');
        }
        total ??= result.totalElements;
        totalPages ??= result.totalPages;
        if (result.number != page ||
            result.totalElements != total ||
            result.totalPages != totalPages ||
            (!result.last && result.items.isEmpty) ||
            result.items.any(
              (item) => item.kind != kind || !seen.add(item.id),
            )) {
          throw const ApiFailure(
            FailureKind.corruptContent,
            'The catalogue changed during refresh. Please retry.',
          );
        }
        received += result.items.length;
        if (received > total ||
            (result.last && received != total) ||
            (!result.last && page + 1 >= totalPages)) {
          throw const ApiFailure(
            FailureKind.corruptContent,
            'Incomplete catalogue response. Please retry.',
          );
        }
        if (!result.last) {
          final prefetch = next = remote.fetch(kind, page + 1);
          // Observe failures now; the loop rethrows them when it awaits.
          unawaited(prefetch.then<void>((_) {}, onError: (Object _) {}));
        }
        await store.stage(generation, result.items);
        if (result.last) break;
        page++;
      }
    } finally {
      // Failures are already observed; drop an unused prefetch.
      next = null;
    }
  }

  void close() {
    _closed = true;
    remote.cancel();
    unawaited(_status.close());
  }
}
