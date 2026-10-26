import 'dart:async';
import 'dart:io';

import '../../offline/application/offline_coordinator.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/connection/application/session_controller.dart';
import '../data/reader_asset_store.dart';
import '../data/reader_repository.dart';
import '../data/reader_store.dart';
import '../data/reading_history.dart';
import '../data/tiered_page_source.dart';
import '../domain/reading_settings.dart';
import '../domain/page_source.dart';
import '../presentation/reader_image_provider.dart';

final readerAssetStoreProvider = Provider<Future<ReaderAssetStore>>((
  ref,
) async {
  final database = await ref.watch(databaseProvider);
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  final store = ReaderAssetStore(
    database,
    Directory('${cache.path}/reader'),
    Directory('${support.path}/downloads'),
  );
  try {
    await store.recoverCache();
  } catch (_) {
    /* Evictable cache failure must not block downloaded reading. */
  }
  return store;
});
final pageNetworkGateProvider = Provider<PageNetworkGate>((ref) {
  ref.watch(sessionProvider.select((state) => state.session?.accountId));
  return PageNetworkGate();
});
final readerRepositoryProvider = FutureProvider.autoDispose<ReaderRepository?>((
  ref,
) async {
  final transport = ref.watch(activeConnectionTransportProvider);
  final account = ref.watch(
    sessionProvider.select(
      (state) =>
          state.phase == SessionPhase.ready ? state.session?.accountId : null,
    ),
  );
  if (account == null) return null;
  var alive = true;
  ReaderRepository? repository;
  ref.onDispose(() {
    alive = false;
    repository?.close();
    ReaderDecodedCache.clearAccount(account);
  });
  await ref.watch(nativeForegroundProvider.future);
  final database = await ref.watch(databaseProvider);
  final assets = await ref.watch(readerAssetStoreProvider);
  if (!alive) return null;
  final controller = ref.read(sessionProvider.notifier);
  final client = transport;
  if (client == null) return null;
  repository = ReaderRepository(
    ReaderStore(database, account),
    assets,
    client,
    ref.watch(pageNetworkGateProvider),
    isCurrent: () => alive && controller.client == client,
  );
  return repository;
});

/// Live reader ownership, including an opening book. Retention consults this
/// only at foreground opportunities; changes never rebuild the application.
final activeReadingBooksProvider = Provider<Set<String>>((ref) => {});

final openReaderProvider = FutureProvider.autoDispose
    .family<OpenReader, String>((ref, bookId) async {
      final active = ref.read(activeReadingBooksProvider)..add(bookId);
      ref.onDispose(() => active.remove(bookId));
      final repository = await ref.watch(readerRepositoryProvider.future);
      if (repository == null) {
        throw StateError('Reader requires an active session');
      }
      var alive = true;
      OpenReader? opened;
      ref.onDispose(() {
        alive = false;
        if (opened != null) repository.release(opened);
      });
      opened = await repository.open(bookId);
      if (!alive) {
        repository.release(opened);
      } else {
        await ReadingHistoryStore(
          repository.store.database,
          repository.store.accountId,
        ).opened(opened.manifest);
      }
      return opened;
    }, retry: (_, _) => null);
final readingSettingsProvider = StreamProvider.autoDispose
    .family<ReadingSettings, String>((ref, bookId) async* {
      final cancellation = CancellationController();
      ref.onDispose(cancellation.cancel);
      final opened = await ref.watch(openReaderProvider(bookId).future);
      final repository = await ref.watch(readerRepositoryProvider.future);
      if (repository == null) return;
      (ReadingMode, ReadingDirection)? analyzed;
      ReadingSettings? emitted;
      await for (final settings in repository.store.settings(opened.manifest)) {
        final identity =
            settings.spreadPairing == SpreadPairing.automatic &&
                settings.mode != ReadingMode.webtoon &&
                !opened.manifest.isDocument
            ? (settings.mode, settings.direction)
            : null;
        var effective = settings;
        if (identity != null && identity != analyzed) {
          analyzed = identity;
          await repository.prepareSpreadPairing(opened.manifest, cancellation);
          if (cancellation.isCancelled) return;
          effective = await repository.store.settings(opened.manifest).first;
        } else if (identity == null) {
          analyzed = null;
        }
        if (cancellation.isCancelled) return;
        if (effective != emitted) {
          emitted = effective;
          yield effective;
        }
      }
    });
