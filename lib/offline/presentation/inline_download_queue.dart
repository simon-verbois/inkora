import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/book_cover.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';

final _transferProgressProvider = StreamProvider.autoDispose
    .family<double?, String>((ref, id) async* {
      final service = await ref.watch(offlineCoordinatorProvider.future);
      if (service != null) yield* service.downloads.progress.watch(id);
    });

/// Independent of the completed gallery: byte/part updates rebuild one row.
class InlineDownloadQueue extends ConsumerWidget {
  const InlineDownloadQueue({super.key, this.search = ''});
  final String search;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(
      downloadsProvider.select(
        (state) =>
            state.asData?.value
                .where(
                  (job) =>
                      job.state != DownloadState.complete &&
                      job.state != DownloadState.cancelled &&
                      job.title.toLowerCase().contains(
                        search.trim().toLowerCase(),
                      ),
                )
                .map((job) => job.id)
                .join('\n') ??
            '',
      ),
    );
    final error = ref.watch(
      downloadsProvider.select((state) => state.hasError),
    );
    if (error) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LText('Unable to load download jobs.'),
        ),
      );
    }
    final jobs = ids.isEmpty ? <String>[] : ids.split('\n');
    return SliverList.builder(
      itemCount: jobs.length,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _TransferRow(key: ValueKey(jobs[index]), id: jobs[index]),
      ),
    );
  }
}

class _TransferRow extends ConsumerStatefulWidget {
  const _TransferRow({required this.id, super.key});
  final String id;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText(
              'Unable to update downloads. Check free space and the selected quota.',
            ),
          ),
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
    final progress = (live ?? ((job.partCount ?? 0) / job.assetCount)).clamp(
      0.0,
      1.0,
    );
    final paused =
        job.state == DownloadState.paused || job.state == DownloadState.failed;
    final colors = Theme.of(context).colorScheme;
    return InkPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(
            item: CatalogueItem(
              kind: CatalogueKind.book,
              id: job.bookId,
              title: job.title,
            ),
            width: 52,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  job.title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                LText(
                  job.error ??
                      switch (job.state) {
                        DownloadState.queued => 'Queued',
                        DownloadState.running => 'Downloading',
                        DownloadState.verifying => 'Preparing download…',
                        DownloadState.paused => 'Paused',
                        DownloadState.failed => 'Download failed',
                        _ => 'Ready offline',
                      },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: colors.outlineVariant,
                        strokeWidth: 3,
                        semanticsLabel: context.tr('Downloading'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    LText('{0} %', arguments: [(progress * 100).round()]),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (s) => paused
                                  ? s.downloads.resume(job.id)
                                  : s.pause(job.id),
                            ),
                      child: LText(paused ? 'Resume download' : 'Pause'),
                    ),
                    IconButton(
                      tooltip: context.tr('Cancel'),
                      onPressed: _busy
                          ? null
                          : () => _run((s) => s.cancel(job.id)),
                      icon: const Icon(InkIcons.x),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
