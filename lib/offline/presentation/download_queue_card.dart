import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/theme/inkora_theme.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';
import 'download_status.dart';

final _transferProgressProvider = StreamProvider.autoDispose
    .family<double?, String>((ref, id) async* {
      final service = await ref.watch(offlineCoordinatorProvider.future);
      if (service != null) yield* service.downloads.progress.watch(id);
    });

/// Membership and state counts of the active queue. Value equality keeps the
/// card from rebuilding on staged-page writes (each row selects its own job).
@immutable
final class QueueSummary {
  const QueueSummary({
    this.ids = const [],
    this.current,
    this.queued = 0,
    this.paused = 0,
    this.failed = 0,
  });

  /// Unfinished jobs: the [current] job first, then account queue order.
  final List<String> ids;
  final String? current;

  /// Counts of the jobs other than [current].
  final int queued, paused, failed;

  bool get isEmpty => ids.isEmpty;

  /// The current job is the running/verifying transfer, otherwise the first
  /// queued, then the first paused or failed job.
  static QueueSummary of(List<DownloadJob> jobs) {
    final active = [
      for (final job in jobs)
        if (job.state != DownloadState.complete &&
            job.state != DownloadState.cancelled)
          job,
    ];
    if (active.isEmpty) return const QueueSummary();
    DownloadJob? first(bool Function(DownloadJob) test) =>
        active.where(test).firstOrNull;
    final current =
        first(
          (job) =>
              job.state == DownloadState.running ||
              job.state == DownloadState.verifying,
        ) ??
        first((job) => job.state == DownloadState.queued) ??
        active.first;
    final others = active.where((job) => job.id != current.id);
    int count(DownloadState state) =>
        others.where((job) => job.state == state).length;
    return QueueSummary(
      ids: [current.id, for (final job in others) job.id],
      current: current.id,
      queued:
          count(DownloadState.queued) +
          count(DownloadState.running) +
          count(DownloadState.verifying),
      paused: count(DownloadState.paused),
      failed: count(DownloadState.failed),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QueueSummary &&
      listEquals(other.ids, ids) &&
      other.current == current &&
      other.queued == queued &&
      other.paused == paused &&
      other.failed == failed;
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(ids), current, queued, paused, failed);
}

/// The active download queue on Downloads: shown only while unfinished jobs
/// exist. The current transfer has a large shared progress ring, its status
/// ("Downloading · 40 %"), the other jobs' counts and its controls; the
/// remaining jobs expand below as compact rows with their own controls.
class DownloadQueueCard extends ConsumerStatefulWidget {
  const DownloadQueueCard({super.key});
  @override
  ConsumerState<DownloadQueueCard> createState() => _DownloadQueueCardState();
}

class _DownloadQueueCardState extends ConsumerState<DownloadQueueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(
      downloadsProvider.select(
        (state) => QueueSummary.of(state.asData?.value ?? const []),
      ),
    );
    final error = ref.watch(
      downloadsProvider.select((state) => state.hasError),
    );
    if (error) {
      return const Padding(
        padding: EdgeInsets.all(InkSpace.lg),
        child: LText('Unable to load download jobs.'),
      );
    }
    if (summary.isEmpty) return const SizedBox.shrink();
    final wifiOnly = ref.watch(
      offlineCoordinatorProvider.select(
        (value) => value.asData?.value?.store.wifiOnly ?? false,
      ),
    );
    final strings = AppStrings.of(context);
    final counts = [
      if (summary.queued > 0) strings.text('Queued: {0}', [summary.queued]),
      if (summary.paused > 0) strings.text('Paused: {0}', [summary.paused]),
      if (summary.failed > 0) strings.text('Failed: {0}', [summary.failed]),
      if (wifiOnly) strings.text('Wi-Fi only'),
    ];
    final others = summary.ids.skip(1).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpace.lg,
        InkSpace.sm,
        InkSpace.lg,
        0,
      ),
      child: InkPanel(
        key: const Key('download-queue'),
        title: 'Download queue',
        icon: InkIcons.downloadSimple,
        action: others.isEmpty
            ? null
            : IconButton(
                key: const Key('download-queue-toggle'),
                tooltip: context.tr(_expanded ? 'Hide queue' : 'Show queue'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? InkIcons.caretUp : InkIcons.caretDown),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TransferRow(
              key: ValueKey('transfer-${summary.current}'),
              id: summary.current!,
              details: counts.isEmpty
                  ? null
                  : counts.reduce((a, b) => strings.text('{0} · {1}', [a, b])),
            ),
            if (_expanded)
              for (final id in others) ...[
                const Divider(height: InkSpace.lg),
                _TransferRow(
                  key: ValueKey('transfer-$id'),
                  id: id,
                  compact: true,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// One job: ring, title, unified status and pause/resume/retry/cancel.
/// It selects only its own job, so another job's page writes never rebuild
/// it; live byte progress comes from the throttled telemetry stream.
class _TransferRow extends ConsumerStatefulWidget {
  const _TransferRow({
    required this.id,
    this.details,
    this.compact = false,
    super.key,
  });
  final String id;
  final String? details;
  final bool compact;
  @override
  ConsumerState<_TransferRow> createState() => _TransferRowState();
}

class _TransferRowState extends ConsumerState<_TransferRow> {
  bool _busy = false;
  Future<void> _run(Future<void> Function(OfflineCoordinator) action) async {
    setState(() => _busy = true);
    try {
      final service = await ref.read(offlineCoordinatorProvider.future);
      if (service != null && service.current) await action(service);
    } catch (_) {
      if (mounted) {
        notifyInk(
          context,
          'Unable to update downloads. Check free space and the selected quota.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(
      downloadsProvider.select(
        (state) =>
            state.asData?.value.where((job) => job.id == widget.id).firstOrNull,
      ),
    );
    if (job == null) return const SizedBox.shrink();
    final live = ref.watch(_transferProgressProvider(widget.id)).asData?.value;
    final ratio = (live ?? ((job.partCount ?? 0) / job.assetCount)).clamp(
      0.0,
      1.0,
    );
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final danger = InkoraColors.of(context).danger;
    final failed = job.state == DownloadState.failed;
    final stopped = failed || job.state == DownloadState.paused;
    final status = downloadStatusLabel(strings, job.state, ratio: ratio);
    final toggle = IconButton(
      key: ValueKey('transfer-toggle-${job.id}'),
      tooltip: context.tr(
        failed
            ? 'Retry download'
            : stopped
            ? 'Resume download'
            : 'Pause',
      ),
      onPressed: _busy
          ? null
          : () => _run(
              (s) => stopped ? s.downloads.resume(job.id) : s.pause(job.id),
            ),
      icon: Icon(
        failed
            ? InkIcons.arrowClockwise
            : stopped
            ? InkIcons.play
            : InkIcons.pause,
      ),
    );
    final cancel = IconButton(
      key: ValueKey('transfer-cancel-${job.id}'),
      tooltip: context.tr('Cancel'),
      onPressed: _busy ? null : () => _run((s) => s.cancel(job.id)),
      icon: const Icon(InkIcons.x),
    );
    final meta = theme.textTheme.meta?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        InkProgressRing(
          value: ratio,
          size: widget.compact ? 32 : 48,
          icon: downloadStateIcon(job.state),
          color: failed ? danger : null,
          label: job.title,
        ),
        const SizedBox(width: InkSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                maxLines: widget.compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: widget.compact
                    ? theme.textTheme.body
                    : theme.textTheme.titleSmall,
              ),
              Text(
                status,
                key: ValueKey('transfer-status-${job.id}'),
                style: meta?.copyWith(color: failed ? danger : null),
              ),
              if (failed && job.error != null)
                LText(job.error!, style: meta?.copyWith(color: danger)),
              if (widget.details != null) Text(widget.details!, style: meta),
            ],
          ),
        ),
        toggle,
        cancel,
      ],
    );
  }
}
