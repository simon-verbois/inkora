import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline/application/offline_coordinator.dart';
import '../../../offline/data/download_store.dart';
import '../../../offline/data/progress_store.dart';
import '../../../offline/domain/progress.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue_filters.dart';
import '../domain/volume_progress.dart';

/// Catalogue mark for [volume]: its snapshot server state is the conflict
/// baseline when this device never observed the book's progress.
ProgressMark progressMark(SeriesVolume volume) => ProgressMark(
  bookId: volume.id,
  pageCount: volume.pageCount,
  server: ProgressSnapshot(
    revision: ProgressIntent.anyRevision,
    pageIndex: volume.serverStatus == ReadingStatus.unread
        ? null
        : volume.serverPage,
    completed: volume.serverStatus == ReadingStatus.completed,
    version: volume.serverModified,
  ),
);

/// Marks [volumes] read or unread for the signed-in account. The intents are
/// written to the durable progress outbox in one transaction (the series page
/// updates immediately), then the account's replay worker is asked to send
/// them; offline, they stay queued and retry with backoff. Returns the
/// number of queued intents.
Future<int> markVolumes(
  WidgetRef ref,
  List<SeriesVolume> volumes, {
  required bool read,
}) async {
  final repository = await ref.read(catalogueRepositoryProvider.future);
  if (repository == null) throw StateError('No account');
  final store = ProgressStore(
    repository.store.database,
    repository.store.accountId,
  );
  final queued = await store.mark([
    for (final volume in volumes) progressMark(volume),
  ], read: read);
  final coordinator = await ref.read(offlineCoordinatorProvider.future);
  // Replay only through the same account's worker; a switched account never
  // sends another account's intents.
  if (queued > 0 &&
      coordinator != null &&
      coordinator.current &&
      coordinator.store.accountId == store.accountId) {
    unawaited(coordinator.sync.replay().catchError((Object _) {}));
  }
  return queued;
}

/// Queues [bookIds] in order (resuming paused/failed jobs). Returns how many
/// were queued and how many failed.
Future<({int done, int failed})> queueVolumeDownloads(
  WidgetRef ref,
  List<String> bookIds,
) async {
  final coordinator = await ref.read(offlineCoordinatorProvider.future);
  if (coordinator == null || !coordinator.current) {
    throw StateError('Download manager unavailable');
  }
  var done = 0, failed = 0;
  for (final id in bookIds) {
    if (!coordinator.current) break;
    try {
      final paused = ref
          .read(downloadsProvider)
          .asData
          ?.value
          .where(
            (job) =>
                job.bookId == id &&
                (job.state == DownloadState.paused ||
                    job.state == DownloadState.failed),
          )
          .lastOrNull;
      if (paused == null) {
        await coordinator.enqueue(id);
      } else {
        await coordinator.downloads.resume(paused.id);
      }
      done++;
    } catch (_) {
      failed++;
    }
  }
  return (done: done, failed: failed);
}
