import '../../app/widgets/inkora_widgets.dart';
import '../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons/inkora_icons.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';
import 'download_status.dart';

/// Queues [bookId], or resumes its paused/failed [job]. Throws when the
/// account's download manager is unavailable or changed.
Future<void> queueBookDownload(
  WidgetRef ref,
  String bookId, {
  DownloadJob? job,
}) async {
  final coordinator = await ref.read(offlineCoordinatorProvider.future);
  if (coordinator == null ||
      !coordinator.current ||
      job != null && job.accountId != coordinator.store.accountId) {
    throw StateError('Download manager unavailable');
  }
  if (job != null) {
    await coordinator.downloads.resume(job.id);
  } else {
    await coordinator.enqueue(bookId);
  }
}

/// Asks before removing a downloaded volume; reading progress is kept.
Future<bool> confirmRemoveDownload(BuildContext context, String title) =>
    confirmInk(
      context,
      title: 'Remove this download?',
      message: "Remove “{0}” from this device? Your reading progress is kept.",
      messageArguments: [title],
      cancelLabel: 'Keep download',
      confirmLabel: 'Remove download',
      destructive: true,
    );

/// Removes every completed copy of [bookId] in the current account. [job],
/// when known, pins the account; [onRemoveDownload] replaces the coordinator
/// (tests and callers that own removal).
Future<void> removeBookDownload(
  WidgetRef ref,
  String bookId, {
  DownloadJob? job,
  Future<void> Function(String jobId)? onRemoveDownload,
}) async {
  final coordinator = await ref.read(offlineCoordinatorProvider.future);
  if (coordinator == null && onRemoveDownload == null ||
      coordinator != null &&
          (!coordinator.current ||
              job != null && coordinator.store.accountId != job.accountId)) {
    throw StateError('Download manager unavailable');
  }
  final account = job?.accountId ?? coordinator?.store.accountId;
  final jobs = coordinator == null
      ? ref.read(downloadsProvider).asData?.value ?? [?job]
      : await coordinator.store.jobs();
  final copies = jobs
      .where(
        (copy) =>
            copy.accountId == account &&
            copy.bookId == bookId &&
            copy.state == DownloadState.complete,
      )
      .toList();
  if (copies.isEmpty && job != null) copies.add(job);
  for (final copy in copies) {
    if (onRemoveDownload != null) {
      await onRemoveDownload(copy.id);
    } else {
      if (!coordinator!.current) throw StateError('Account changed');
      await coordinator.cancel(copy.id);
    }
  }
}

/// One trailing volume action, backed by the account's persistent job state.
class DownloadBookAction extends ConsumerStatefulWidget {
  const DownloadBookAction({
    required this.bookId,
    required this.title,
    this.enabled = true,
    this.completedJob,
    this.onRemoveDownload,
    super.key,
  });
  final String bookId, title;
  final bool enabled;
  final DownloadJob? completedJob;
  final Future<void> Function(String jobId)? onRemoveDownload;
  @override
  ConsumerState<DownloadBookAction> createState() => _DownloadBookActionState();
}

class _DownloadBookActionState extends ConsumerState<DownloadBookAction> {
  bool _busy = false;

  Future<void> _download(DownloadJob? job) async {
    setState(() => _busy = true);
    try {
      await queueBookDownload(ref, widget.bookId, job: job);
    } catch (_) {
      if (mounted) {
        notifyInk(
          context,
          'Unable to queue this download. Check connection and storage quota.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(DownloadJob job) async {
    if (_busy) return;
    try {
      if (!await confirmRemoveDownload(context, widget.title) || !mounted) {
        return;
      }
      setState(() => _busy = true);
      await removeBookDownload(
        ref,
        widget.bookId,
        job: job,
        onRemoveDownload: widget.onRemoveDownload,
      );
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to remove this download. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Each row depends only on its own book's jobs; other books' progress
    // and part writes do not rebuild it.
    final bookId = widget.bookId;
    final (:loading, :completedJob, :latestJob) = ref.watch(
      downloadsProvider.select((data) {
        DownloadJob? completed, latest;
        for (final job in data.asData?.value ?? const <DownloadJob>[]) {
          if (job.bookId != bookId || job.state == DownloadState.cancelled) {
            continue;
          }
          latest = job;
          if (job.state == DownloadState.complete) completed = job;
        }
        return (
          loading: data.isLoading,
          completedJob: completed,
          latestJob: latest,
        );
      }),
    );
    final completed = completedJob ?? widget.completedJob;
    final job = completed ?? latestJob;
    final pending =
        job != null &&
        (job.state == DownloadState.queued ||
            job.state == DownloadState.running ||
            job.state == DownloadState.verifying);
    final waiting = _busy || loading && completed == null;
    final label = completed != null
        ? 'Remove download'
        : pending
        ? context.tr('Manage download · {0}', [
            context.tr(downloadStateLabel(job.state)),
          ])
        : job?.state == DownloadState.paused
        ? 'Resume download'
        : job?.state == DownloadState.failed
        ? 'Retry download'
        : 'Download volume';
    return IconButton(
      key: ValueKey('volume-download-${widget.bookId}'),
      tooltip: context.tr(waiting ? 'Preparing download…' : label),
      onPressed: waiting || !widget.enabled && completed == null
          ? null
          : completed != null
          ? () => _remove(completed)
          : pending
          ? () => context.go('/downloads')
          : () => _download(job),
      icon: waiting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              completed != null
                  ? InkIcons.trash
                  : pending
                  ? InkIcons.hourglassMedium
                  : InkIcons.downloadSimple,
            ),
    );
  }
}
