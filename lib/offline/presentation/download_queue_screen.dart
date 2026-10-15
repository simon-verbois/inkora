import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/book_cover.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';

class DownloadQueueScreen extends ConsumerStatefulWidget {
  const DownloadQueueScreen({super.key});
  @override
  ConsumerState<DownloadQueueScreen> createState() =>
      _DownloadQueueScreenState();
}

class _DownloadQueueScreenState extends ConsumerState<DownloadQueueScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function(OfflineCoordinator) action) async {
    setState(() => _busy = true);
    try {
      final coordinator = await ref.read(offlineCoordinatorProvider.future);
      if (coordinator != null) await action(coordinator);
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
    final coordinator = ref.watch(offlineCoordinatorProvider);
    final jobs = ref.watch(downloadsProvider);
    final all =
        jobs.asData?.value
            .where((job) => job.state != DownloadState.cancelled)
            .toList() ??
        [];
    final visible = all
        .where((job) => job.state != DownloadState.complete)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const LText('Download queue')),
      body: SingleChildScrollView(
        child: InkContent(
          child: coordinator.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => InkEmptyState(
              icon: InkIcons.warningCircle,
              title: context.tr("Offline storage unavailable"),
              message: context.tr("Unable to open offline storage."),
              label: context.tr("Retry"),
              action: () => ref.invalidate(offlineCoordinatorProvider),
            ),
            data: (service) => service == null
                ? InkEmptyState(
                    icon: InkIcons.checkCircle,
                    title: context.tr("Preparing your offline shelf"),
                    message: context.tr(
                      "Offline storage becomes available with your active account.",
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (jobs.hasError)
                        const InkPanel(
                          child: LText('Unable to load download jobs.'),
                        ),
                      if (jobs.isLoading) const LinearProgressIndicator(),
                      if (jobs.hasValue && visible.isEmpty)
                        InkPanel(
                          child: InkEmptyState(
                            icon: InkIcons.downloadSimple,
                            title: context.tr("No downloads in the queue"),
                            message: context.tr(
                              "Download a volume using the button beside its name.",
                            ),
                            label: context.tr("Browse libraries"),
                            action: () => context.go('/libraries'),
                          ),
                        ),
                      for (final job in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BookCover(
                                      item: CatalogueItem(
                                        kind: CatalogueKind.book,
                                        id: job.manifest.bookId,
                                        title: job.manifest.title,
                                        modified:
                                            job.manifest.revision.hashCode,
                                        pageCount: job.manifest.pages.length,
                                      ),
                                      width: 60,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            job.manifest.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          LText(
                                            job.error ??
                                                switch (job.state) {
                                                  DownloadState.queued =>
                                                    'Queued',
                                                  DownloadState.running =>
                                                    'Downloading',
                                                  DownloadState.verifying =>
                                                    job.manifest.isDocument
                                                        ? 'Preparing download…'
                                                        : 'Checking downloaded pages',
                                                  DownloadState.complete =>
                                                    'Ready offline',
                                                  DownloadState.paused =>
                                                    'Paused',
                                                  DownloadState.failed =>
                                                    'Download failed',
                                                  _ => 'Cancelled',
                                                },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (_) {
                                    final total = job.manifest.assetCount;
                                    final done =
                                        job.state == DownloadState.complete
                                        ? total
                                        : job.partCount ?? 0;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        LinearProgressIndicator(
                                          value: done / total,
                                          semanticsLabel: context.tr(
                                            job.manifest.isDocument
                                                ? "Download"
                                                : "Downloaded pages",
                                          ),
                                        ),
                                        if (!job.manifest.isDocument) ...[
                                          const SizedBox(height: 8),
                                          LText(
                                            "{0}/{1} pages",
                                            arguments: [done, total],
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if ({
                                      DownloadState.running,
                                      DownloadState.queued,
                                      DownloadState.verifying,
                                    }.contains(job.state))
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () =>
                                                  _run((s) => s.pause(job.id)),
                                        child: const LText('Pause'),
                                      ),
                                    if ({
                                      DownloadState.paused,
                                      DownloadState.failed,
                                    }.contains(job.state))
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _run(
                                                (s) =>
                                                    s.downloads.resume(job.id),
                                              ),
                                        child: const LText('Resume'),
                                      ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run((s) => s.cancel(job.id)),
                                      child: const LText('Cancel'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
