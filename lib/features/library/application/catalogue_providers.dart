import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/session_controller.dart';
import '../data/catalogue_repository.dart';
import '../data/catalogue_store.dart';
import '../data/komga_catalogue_remote.dart';
import '../data/resume_repository.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
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
