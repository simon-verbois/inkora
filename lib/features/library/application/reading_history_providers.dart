import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/session_controller.dart';
import '../data/reading_history_repository.dart';
import 'catalogue_providers.dart';

/// Account-owned history repository. Created when the history screen opens
/// (auto-disposed with it); creation starts one server refresh, so the
/// server pages are refreshed on open, never on rebuilds.
final readingHistoryRepositoryProvider =
    FutureProvider.autoDispose<ReadingHistoryRepository?>((ref) async {
      final transport = ref.watch(activeConnectionTransportProvider);
      var alive = true;
      ReadingHistoryRepository? repository;
      ref.onDispose(() {
        alive = false;
        repository?.close();
      });
      final controller = ref.read(sessionProvider.notifier);
      final catalogue = await ref.watch(catalogueRepositoryProvider.future);
      if (!alive || catalogue == null) return null;
      final client = transport;
      repository = ReadingHistoryRepository(
        catalogue.store,
        fetch: client == null
            ? null
            : (page, size, token) => client.cataloguePage(
                'book',
                parseServerHistoryEntry,
                page: page,
                size: size,
                history: true,
                parseInBackground: true,
                cancelToken: token,
              ),
        isCurrent: () => alive && controller.client == client,
      );
      unawaited(repository.refresh());
      return repository;
    });

final readingHistoryProvider = StreamProvider.autoDispose<ReadingHistoryView>((
  ref,
) async* {
  final repository = await ref.watch(readingHistoryRepositoryProvider.future);
  if (repository == null) {
    yield const ReadingHistoryView();
    return;
  }
  yield* repository.watch();
});
