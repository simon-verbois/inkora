import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../reader/application/reader_providers.dart';
import '../../../reader/domain/page_source.dart';
import '../../connection/application/session_controller.dart';
import '../data/cover_repository.dart';

final coverCacheDirectoryProvider = Provider<Future<Directory>>((ref) async {
  final cache = await getApplicationCacheDirectory();
  return Directory('${cache.path}/covers');
});

final coverRepositoryProvider = FutureProvider<CoverRepository?>((ref) async {
  final account = ref.watch(
    sessionProvider.select(
      (state) =>
          state.phase == SessionPhase.ready ? state.session?.accountId : null,
    ),
  );
  if (account == null) return null;
  final gate = ref.watch(pageNetworkGateProvider);
  final client = ref.read(sessionProvider.notifier).client;
  if (client == null) return null;
  var alive = true;
  CoverRepository? repository;
  ref.onDispose(() {
    alive = false;
    repository?.close();
  });
  final directory = await ref.watch(coverCacheDirectoryProvider);
  if (!alive) return null;
  return repository = CoverRepository(client, gate, directory, account);
}, retry: (_, _) => null);

final coverProvider = FutureProvider.autoDispose.family<Uint8List?, CoverKey>((
  ref,
  key,
) {
  final signal = CancellationController();
  ref.onDispose(signal.cancel);
  final state = ref.watch(coverRepositoryProvider);
  FutureOr<Uint8List?> acquire(CoverRepository? repository) {
    if (!ref.mounted || signal.isCancelled || repository == null) return null;
    final release = repository.track(key);
    final updates = repository.changes.listen((changed) {
      if (changed == key && ref.mounted) ref.invalidateSelf();
    });
    ref.onDispose(() {
      release();
      unawaited(updates.cancel());
    });
    final cached = repository.peek(key);
    if (cached != null) {
      unawaited(repository.revalidate(key, onlyIfStale: true));
      return cached;
    }
    return repository.load(key, signal).then((bytes) {
      if (ref.mounted && bytes != null) {
        unawaited(repository.revalidate(key, onlyIfStale: true));
      }
      return bytes;
    });
  }

  if (state.hasValue) {
    return acquire(state.asData?.value);
  }
  return ref.watch(coverRepositoryProvider.future).then((repository) {
    if (signal.isCancelled) return null;
    return acquire(repository);
  });
}, retry: (_, _) => null);
