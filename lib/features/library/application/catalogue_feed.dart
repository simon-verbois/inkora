import 'dart:async';

import '../data/catalogue_store.dart';
import '../domain/catalogue.dart';

final class CatalogueFeedState {
  const CatalogueFeedState({
    this.page = const LocalCataloguePage([], 0, null),
    this.loading = true,
    this.error = false,
  });
  final LocalCataloguePage page;
  final bool loading, error;
  bool get hasMore => page.items.length < page.total;
}

/// A retained SQLite prefix grows in small batches. Each published generation
/// replaces the prefix atomically, preserving sort/membership order and avoiding
/// duplicate rows from concatenating different catalogue generations.
final class CatalogueFeed {
  CatalogueFeed(this.store, this.query) {
    _subscribe();
  }
  final CatalogueStore store;
  final CatalogueQuery query;
  static const batchSize = 60;
  int _limit = batchSize, _generation = 0;
  bool _closed = false;
  CatalogueFeedState _state = const CatalogueFeedState();
  final _updates = StreamController<CatalogueFeedState>.broadcast(sync: true);
  StreamSubscription<LocalCataloguePage>? _subscription;
  CatalogueFeedState get state => _state;
  Stream<CatalogueFeedState> get stream => Stream.multi((controller) {
    final subscription = _updates.stream.listen(
      controller.add,
      onDone: controller.close,
    );
    controller.add(_state);
    controller.onCancel = subscription.cancel;
  });

  void _emit(CatalogueFeedState state) {
    if (_closed) return;
    _state = state;
    _updates.add(state);
  }

  void _subscribe() {
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = store
        .watchWindow(query, () => _limit)
        .listen(
          (page) {
            if (_closed || generation != _generation) return;
            _emit(CatalogueFeedState(page: page, loading: false));
          },
          onError: (Object error) {
            if (_closed || generation != _generation) return;
            _emit(
              CatalogueFeedState(
                page: _state.page,
                loading: false,
                error: true,
              ),
            );
          },
        );
  }

  /// Appends only the next batch (keyed by offset) instead of re-reading the
  /// growing prefix, so scrolling a long catalogue stays linear. A batch from
  /// a different publication is discarded; the publication watch re-reads the
  /// full prefix with the new limit and replaces the state atomically.
  void loadMore() {
    if (_closed || _state.loading || !_state.hasMore) return;
    final previous = _state.page;
    final offset = previous.items.length;
    final generation = _generation;
    _limit = offset + batchSize;
    _emit(CatalogueFeedState(page: previous));
    store
        .read(query, itemLimit: batchSize, itemOffset: offset)
        .then(
          (batch) {
            if (_closed || generation != _generation) return;
            if (!identical(_state.page, previous)) return; // Watch replaced it.
            if (batch.lastUpdated != previous.lastUpdated ||
                batch.total != previous.total) {
              _subscribe();
              return;
            }
            _emit(
              CatalogueFeedState(
                page: LocalCataloguePage(
                  List.unmodifiable([...previous.items, ...batch.items]),
                  batch.total,
                  batch.lastUpdated,
                ),
                loading: false,
              ),
            );
          },
          onError: (Object _) {
            if (_closed || generation != _generation) return;
            if (!identical(_state.page, previous)) return;
            _limit = offset;
            _emit(
              CatalogueFeedState(page: previous, loading: false, error: true),
            );
          },
        );
  }

  void retry() {
    if (_closed) return;
    _emit(CatalogueFeedState(page: _state.page));
    _subscribe();
  }

  void close() {
    _closed = true;
    unawaited(_subscription?.cancel());
    unawaited(_updates.close());
  }
}
