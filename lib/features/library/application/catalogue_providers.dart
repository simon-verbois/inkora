import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/session_controller.dart';
import '../data/catalogue_repository.dart';
import '../data/catalogue_store.dart';
import '../data/komga_catalogue_remote.dart';
import '../data/resume_repository.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
import '../domain/volume_progress.dart';
import 'navigation_retention.dart';
import 'catalogue_feed.dart';

final catalogueFeedProvider = FutureProvider.autoDispose
    .family<CatalogueFeed?, CatalogueQuery>((ref, query) async {
      var alive = true;
      CatalogueFeed? feed;
      ref.onDispose(() {
        alive = false;
        feed?.close();
      });
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (!alive || repository == null) return null;
      return feed = CatalogueFeed(repository.store, query);
    });

final catalogueFeedStateProvider = StreamProvider.autoDispose
    .family<CatalogueFeedState, CatalogueQuery>((ref, query) async* {
      final feed = await ref.watch(catalogueFeedProvider(query).future);
      if (feed == null) {
        yield const CatalogueFeedState(loading: false);
        return;
      }
      yield* retainNavigationStream(ref, feed.stream);
    });

final catalogueRepositoryProvider =
    FutureProvider.autoDispose<CatalogueRepository?>((ref) async {
      final account = ref.watch(
        sessionProvider.select(
          (state) => state.phase == SessionPhase.ready
              ? state.session?.accountId
              : null,
        ),
      );
      if (account == null) return null;
      var alive = true;
      CatalogueRepository? repository;
      ref.onDispose(() {
        alive = false;
        repository?.close();
      });
      final controller = ref.read(sessionProvider.notifier);
      final database = await ref.watch(databaseProvider);
      if (!alive) return null;
      final client = controller.client;
      if (client == null) return null;
      repository = CatalogueRepository(
        CatalogueStore(database, account),
        KomgaCatalogueRemote(client),
        isCurrent: () => alive && controller.client == client,
      );
      unawaited(repository.refreshIfStale());
      return repository;
    });

final cataloguePageProvider = StreamProvider.autoDispose
    .family<LocalCataloguePage, CatalogueQuery>((ref, query) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield const LocalCataloguePage([], 0, null);
        return;
      }
      yield* retainNavigationStream(ref, repository.store.watch(query));
    });
final catalogueOverviewProvider =
    StreamProvider.autoDispose<Map<CatalogueKind, int>>((ref) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield {};
        return;
      }
      yield* retainNavigationStream(ref, repository.store.overview());
    });
final catalogueRefreshProvider =
    StreamProvider.autoDispose<CatalogueRefreshState>((ref) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield const CatalogueRefreshState();
        return;
      }
      yield* repository.status;
    });
final catalogueItemProvider = StreamProvider.autoDispose
    .family<CatalogueItem?, (CatalogueKind, String)>((ref, key) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield null;
        return;
      }
      yield* retainNavigationStream(ref, repository.store.item(key.$1, key.$2));
    });

final resumeRepositoryProvider = FutureProvider.autoDispose<ResumeRepository?>((
  ref,
) async {
  var alive = true;
  ResumeRepository? repository;
  ref.onDispose(() {
    alive = false;
    repository?.close();
  });
  final controller = ref.read(sessionProvider.notifier);
  final catalogue = await ref.watch(catalogueRepositoryProvider.future);
  if (!alive || catalogue == null) return null;
  final client = controller.client;
  if (client == null) return null;
  repository = ResumeRepository(
    catalogue.store,
    client,
    isCurrent: () => alive && controller.client == client,
  );
  unawaited(repository.refresh());
  return repository;
});

final resumeEntriesProvider = StreamProvider.autoDispose<List<ResumeEntry>>((
  ref,
) async* {
  final repository = await ref.watch(resumeRepositoryProvider.future);
  if (repository == null) {
    yield [];
    return;
  }
  yield* retainNavigationStream(ref, repository.watch());
});

/// Ordered lean volumes of one series (publication-driven, retained briefly
/// for back navigation like other catalogue queries).
final seriesVolumesProvider = StreamProvider.autoDispose
    .family<List<SeriesVolume>, String>((ref, seriesId) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield const [];
        return;
      }
      yield* retainNavigationStream(
        ref,
        repository.store.watchSeriesVolumes(seriesId),
      );
    });

/// Whether any page showing a series is on screen. Pages register as owners;
/// with no owner (for example a provider read outside a page) it is visible.
class SeriesPageVisibility {
  final _owners = <Object, bool>{};
  final _listeners = <void Function()>[];

  bool get visible => _owners.isEmpty || _owners.containsValue(true);

  void set(Object owner, bool visible) {
    final before = this.visible;
    _owners[owner] = visible;
    _notify(before);
  }

  void remove(Object owner) {
    final before = visible;
    if (_owners.remove(owner) != null) _notify(before);
  }

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify(bool before) {
    if (visible == before) return;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

final seriesPageVisibilityProvider = Provider.autoDispose
    .family<SeriesPageVisibility, String>((ref, _) => SeriesPageVisibility());

/// Listens to [open] only while [visibility] is visible. Hiding cancels the
/// source (no query per reading write under the reader); showing again
/// re-subscribes, which reads once. Emissions equal to the last one are
/// dropped by [equals].
Stream<T> whileVisible<T>(
  SeriesPageVisibility visibility,
  Stream<T> Function() open, {
  required bool Function(T a, T b) equals,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? source;
  T? last;
  var emitted = false;
  void update() {
    if (visibility.visible) {
      source ??= open().listen((value) {
        if (emitted && equals(last as T, value)) return;
        emitted = true;
        last = value;
        controller.add(value);
      }, onError: controller.addError);
    } else {
      final previous = source;
      source = null;
      previous?.cancel();
    }
  }

  controller = StreamController<T>(
    onListen: () {
      visibility.addListener(update);
      update();
    },
    onCancel: () {
      visibility.removeListener(update);
      final previous = source;
      source = null;
      return previous?.cancel();
    },
  );
  return controller.stream;
}

/// Device progress of one series' books. Not retained after the page closes:
/// it wakes on reading writes, so it lives only while a series page needs it
/// and pauses while every such page is hidden (covered by the reader or in an
/// inactive branch), refreshing once when one is shown again.
final seriesLocalProgressProvider = StreamProvider.autoDispose
    .family<Map<String, LocalVolumeProgress>, String>((ref, seriesId) async* {
      final visibility = ref.watch(seriesPageVisibilityProvider(seriesId));
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield const {};
        return;
      }
      yield* whileVisible(
        visibility,
        () => repository.store.watchSeriesLocalProgress(seriesId),
        equals: CatalogueStore.sameProgress,
      );
    });

/// The series' server-shelf position (in-progress, not On Deck), used when
/// the catalogue snapshot is older than the shelf.
final _seriesShelfProvider = Provider.autoDispose
    .family<({String id, int pageIndex, double? ratio})?, String>(
      (ref, seriesId) => ref.watch(
        resumeEntriesProvider.select((state) {
          for (final entry in state.asData?.value ?? const <ResumeEntry>[]) {
            if (entry.onDeck || entry.item.seriesId != seriesId) continue;
            return (
              id: entry.item.id,
              pageIndex: entry.pageIndex,
              ratio: entry.pageKnown || entry.totalProgression != null
                  ? entry.progress.toDouble()
                  : null,
            );
          }
          return null;
        }),
      ),
    );

/// Effective per-volume progress of a series. Value equality keeps
/// `select`-ing rows from rebuilding unless their own volume changes.
final seriesProgressProvider = Provider.autoDispose
    .family<AsyncValue<SeriesProgress>, String>((ref, seriesId) {
      final volumes = ref.watch(seriesVolumesProvider(seriesId));
      final local = ref.watch(seriesLocalProgressProvider(seriesId));
      final shelf = ref.watch(_seriesShelfProvider(seriesId));
      if (volumes.hasError) {
        return AsyncValue.error(volumes.error!, volumes.stackTrace!);
      }
      final list = volumes.asData?.value;
      if (list == null) return const AsyncValue.loading();
      final overrides =
          local.asData?.value ?? const <String, LocalVolumeProgress>{};
      return AsyncValue.data(
        SeriesProgress(list, {
          for (final volume in list)
            volume.id: resolveVolumeProgress(
              volume,
              overrides[volume.id],
              shelf: shelf?.id == volume.id
                  ? (pageIndex: shelf!.pageIndex, ratio: shelf.ratio)
                  : null,
            ),
        }),
      );
    });
