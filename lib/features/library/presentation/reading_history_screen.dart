import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../reader/data/reading_history.dart';
import '../../connection/application/session_controller.dart';
import '../application/catalogue_providers.dart';
import '../application/reading_history_providers.dart';
import '../data/reading_history_repository.dart';
import '../domain/catalogue_filters.dart';
import '../domain/reading_history.dart';
import 'book_cover.dart';
import 'progress_format.dart';
import 'volume_browser.dart';

/// Reading history: this device's reader opens merged with Komga read
/// progress, newest first, grouped by day. Tapping a book opens it directly
/// (like Continue reading); Back returns here. Clear removes only this
/// device's opens; server progress is unaffected and stays listed.
class ReadingHistoryScreen extends ConsumerStatefulWidget {
  const ReadingHistoryScreen({super.key});
  @override
  ConsumerState<ReadingHistoryScreen> createState() =>
      _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends ConsumerState<ReadingHistoryScreen> {
  bool _loadingMore = false;

  Future<void> _clear() async {
    final confirmed = await confirmInk(
      context,
      title: 'Clear history?',
      message: 'Books opened on this device are removed from this list. Reading progress and bookmarks are kept, and books with reading progress on Komga stay listed.',
      confirmLabel: 'Clear history',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final account = ref.read(sessionProvider).session?.accountId;
    if (account == null) return;
    try {
      await ReadingHistoryStore(
        await ref.read(databaseProvider),
        account,
      ).clear();
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to clear history.');
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final repository = await ref.read(
        readingHistoryRepositoryProvider.future,
      );
      await repository?.loadMore();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(readingHistoryProvider);
    final deviceCount = history.asData?.value.deviceCount ?? 0;
    return Scaffold(
      appBar: InkScreenHeader(
        title: const LText('Reading history'),
        actions: [
          IconButton(
            key: const Key('history-clear'),
            tooltip: context.tr('Clear history'),
            icon: const Icon(InkIcons.trash),
            onPressed: deviceCount > 0 ? _clear : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          child: history.when(
            loading: () =>
                const SingleChildScrollView(child: InkSkeletonList()),
            error: (_, _) => const Center(
              child: SingleChildScrollView(
                child: InkEmptyState(
                  icon: InkIcons.cloudSlash,
                  title: 'Reading history unavailable',
                ),
              ),
            ),
            data: (view) => view.entries.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: InkEmptyState(
                        key: const Key('history-empty'),
                        icon: InkIcons.clockCounterClockwise,
                        title: 'No reading history yet.',
                        message: 'Books you open on this device and books with reading progress on Komga appear here.',
                        label: 'Browse catalogue',
                        action: () => context.go('/'),
                      ),
                    ),
                  )
                : _HistoryList(
                    view: view,
                    loadingMore: _loadingMore,
                    onLoadMore: _loadMore,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.view,
    required this.loadingMore,
    required this.onLoadMore,
  });
  final ReadingHistoryView view;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Flatten day headings and rows once per emission; rows build lazily.
    final rows = <Object>[];
    HistoryPeriod? last;
    for (final entry in view.entries) {
      final period = historyPeriod(entry.at, now);
      if (period != last) rows.add(period);
      last = period;
      rows.add((entry, period));
    }
    final theme = Theme.of(context);
    return ListView.builder(
      key: const Key('history-list'),
      padding: EdgeInsets.only(
        left: InkSpace.lg,
        right: InkSpace.lg,
        bottom: MediaQuery.paddingOf(context).bottom + InkSpace.lg,
      ),
      itemCount: rows.length + (view.more ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpace.lg),
            child: Center(
              child: OutlinedButton(
                key: const Key('history-load-more'),
                onPressed: loadingMore ? null : onLoadMore,
                child: const LText('Load more'),
              ),
            ),
          );
        }
        final row = rows[index];
        if (row is HistoryPeriod) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? InkSpace.sm : InkSpace.lg,
              bottom: InkSpace.xs,
            ),
            child: Semantics(
              header: true,
              child: LText(
                historyPeriodLabel(row),
                style: theme.textTheme.sectionTitle?.copyWith(
                  color: InkoraColors.of(context).heading,
                ),
              ),
            ),
          );
        }
        final (entry, period) = row as (HistoryEntry, HistoryPeriod);
        return HistoryRow(
          key: ValueKey('history-${entry.bookId}'),
          entry: entry,
          period: period,
        );
      },
    );
  }
}

/// Time of an entry within its day group: the time for Today/Yesterday, the
/// weekday for This week, the date for Earlier.
String historyTimeLabel(
  BuildContext context,
  DateTime at,
  HistoryPeriod period,
) {
  final local = at.toLocal();
  final material = MaterialLocalizations.of(context);
  switch (period) {
    case HistoryPeriod.today || HistoryPeriod.yesterday:
      return material.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
    case HistoryPeriod.thisWeek:
      try {
        return DateFormat.EEEE(Localizations.localeOf(context).toString())
            .format(local);
      } catch (_) {
        return material.formatMediumDate(local);
      }
    case HistoryPeriod.earlier:
      return material.formatMediumDate(local);
  }
}

/// One history row: cover, series (or book) title, book title and progress.
/// and a thin progress bar while reading. The open book's live position
/// comes from the Continue reading entries, selected for this book only.
class HistoryRow extends ConsumerWidget {
  const HistoryRow({super.key, required this.entry, required this.period});
  final HistoryEntry entry;
  final HistoryPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final live = entry.status == ReadingStatus.inProgress
        ? ref.watch(
            resumeEntriesProvider.select((value) {
              final resume = value.asData?.value
                  .where((item) => item.item.id == entry.bookId)
                  .firstOrNull;
              return resume == null || resume.onDeck
                  ? null
                  : formatResumeProgress(strings, resume);
            }),
          )
        : null;
    final progress = live ?? formatHistoryProgress(strings, entry);
    final comic = !entry.isEbook && entry.seriesTitle != null;
    final title = comic ? entry.seriesTitle! : entry.title;
    final subtitle = strings.text('{0} · {1}', [
      progress.label,
      historyTimeLabel(context, entry.at, period),
    ]);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .25)),
        ),
      ),
      child: Semantics(
        container: true,
        button: true,
        enabled: entry.available,
        label: '$title, $subtitle',
        excludeSemantics: true,
        child: InkWell(
          onTap: entry.available
              ? () => context.pushNamed(
                  'reader',
                  pathParameters: {'id': entry.bookId},
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpace.sm),
            child: Row(
              children: [
                BookCover(item: entry.item, width: 40),
                const SizedBox(width: InkSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: volumeTitleStyle(theme),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.meta?.copyWith(
                          color: progress.state == ReadingState.read
                              ? InkoraColors.of(context).success
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (progress.state == ReadingState.reading &&
                          progress.ratio != null) ...[
                        const SizedBox(height: InkSpace.xs),
                        LinearProgressIndicator(
                          value: progress.ratio,
                          minHeight: 3,
                          borderRadius: InkRadius.small,
                        ),
                      ],
                    ],
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
