import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/theme/inkora_theme.dart';
import '../../app/widgets/ink_filter_bar.dart';
import '../../app/widgets/ink_screen_header.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/domain/catalogue_filters.dart';
import '../../features/library/domain/volume_progress.dart';
import '../../features/library/presentation/book_cover.dart';
import '../../features/library/presentation/catalogue_card.dart';
import '../../features/library/presentation/catalogue_filters_sheet.dart';
import '../../features/library/presentation/catalogue_grid.dart';
import '../../features/library/presentation/catalogue_presentation.dart';
import '../../features/library/presentation/catalogue_toolbar.dart';
import '../../features/library/presentation/progress_format.dart';
import '../../features/library/presentation/reading_filter_chips.dart';
import '../../features/library/presentation/volume_actions.dart';
import '../../features/library/presentation/volume_browser.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';
import 'download_book_action.dart';
import 'download_queue_card.dart';
import 'download_status.dart';

/// Size and read count of a downloaded group: "3 volumes · 412 MiB · 1/3
/// read" for a series, "EPUB · 1.4 MiB · In progress" for an ebook.
String downloadGroupSummary(BuildContext context, DownloadedSeries group) {
  final strings = AppStrings.of(context);
  final bytes = group.books.fold<int>(0, (sum, book) => sum + book.bytes);
  final List<String> parts;
  if (group.item.kind == CatalogueKind.series) {
    final read = group.books
        .where((book) => book.item.readingStatus == ReadingStatus.completed)
        .length;
    parts = [
      strings.quantity(group.books.length, 'volume'),
      formatBytes(strings, bytes),
      if (read > 0) strings.text('{0}/{1} read', [read, group.books.length]),
    ];
  } else {
    final item = group.item;
    parts = [
      if (item.isEbook)
        facetValueLabel(
          context,
          CatalogueFacet.mediaType,
          item.metadata.mediaType,
        )
      else if (item.pageCount > 0)
        strings.quantity(item.pageCount, 'page'),
      formatBytes(strings, bytes),
      formatItemProgress(strings, item).label,
    ];
  }
  return parts.reduce((a, b) => strings.text('{0} · {1}', [a, b]));
}

/// Removes every downloaded volume of [group] after one confirmation.
/// Reading progress is kept.
Future<void> removeDownloadedGroup(
  BuildContext context,
  WidgetRef ref,
  DownloadedSeries group, {
  Future<void> Function(String jobId)? onRemoveDownload,
}) async {
  final strings = AppStrings.of(context);
  final confirmed = group.item.kind == CatalogueKind.series
      ? await confirmInk(
          context,
          title: 'Remove these downloads?',
          message: 'Remove {0} of “{1}” from this device? Your reading progress is kept.',
          messageArguments: [
            strings.quantity(group.books.length, 'volume'),
            group.item.title,
          ],
          confirmLabel: 'Remove downloads',
          destructive: true,
        )
      : await confirmRemoveDownload(context, group.item.title);
  if (!confirmed || !context.mounted) return;
  try {
    for (final book in group.books) {
      await removeBookDownload(
        ref,
        book.item.id,
        job: book.job,
        onRemoveDownload: onRemoveDownload,
      );
    }
  } catch (_) {
    if (context.mounted) {
      notifyInk(context, 'Unable to remove this download. Try again.');
    }
  }
}

/// Downloads. The root shows the storage summary, the active queue (only
/// while transfers exist), then the shared filter bar and the content: comic
/// series (tap: their downloaded volumes) and individual books (tap: read
/// offline), as a list by default or as the cover grid. A series route lists
/// its downloaded volumes with the shared volume rows.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key, this.onRemoveDownload, this.seriesId});
  final Future<void> Function(String jobId)? onRemoveDownload;
  final String? seriesId;
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _browser = VolumeBrowserController();
  late final _actions = VolumeActions(
    open: (volume) => openBookReader(context, volume.item),
    mark: _mark,
  );
  late CatalogueSort _sort = widget.seriesId == null
      ? CatalogueSort.title
      : CatalogueSort.sequence;
  bool _grid = false;
  String _term = '';
  Timer? _debounce;
  MetadataFilters _metadataFilters = const MetadataFilters();

  bool get _root => widget.seriesId == null;

  Future<void> _mark(SeriesVolume volume, {required bool read}) async {
    try {
      await markVolumes(ref, [volume], read: read);
      if (mounted) {
        notifyInk(
          context,
          'Reading status updated: {0}',
          arguments: [AppStrings.of(context).quantity(1, 'volume')],
        );
      }
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to save reading progress.');
    }
  }

  /// Keystrokes never rebuild the screen (the field owns its clear button);
  /// the term changes once per 180-ms pause.
  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      final term = value.trim().toLowerCase();
      if (mounted && term != _term) _change(() => _term = term);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    if (_term.isNotEmpty) _change(() => _term = '');
  }

  /// Items of this view (root: series/ebook groups; series: its volumes).
  Iterable<CatalogueItem> _scopeItems(List<DownloadedSeries> all) => _root
      ? all.map((group) => group.item)
      : all
            .where((group) => group.item.id == widget.seriesId)
            .expand((group) => group.books.map((book) => book.item));

  static bool _matches(CatalogueItem item, MetadataFilters filters) =>
      filters.matches(item.metadata) &&
      (filters.readingStatus == ReadingStatus.any ||
          item.readingStatus == filters.readingStatus);

  Future<void> _filters() async {
    final all = ref.read(downloadedReadingSeriesProvider).asData?.value ?? [];
    final items = _scopeItems(all).toList(growable: false);
    final term = _term;
    final options = <CatalogueFacet, List<String>>{};
    for (final facet in CatalogueFacet.values) {
      final values =
          items
              .expand((item) => facet.entries(item.metadata))
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (values.isNotEmpty) options[facet] = values;
    }
    final result = await showInkPopup<CatalogueFilterResult>(
      context: context,
      child: CatalogueFiltersSheet(
        options: Future.value(options),
        filters: _metadataFilters,
        // The loaded offline shelf is small and already in memory.
        count: (filters, _) async => items
            .where(
              (item) =>
                  item.title.toLowerCase().contains(term) &&
                  _matches(item, filters),
            )
            .length,
      ),
    );
    if (mounted && result != null) {
      _change(() => _metadataFilters = result.filters);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _browser.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(CatalogueItem item) {
    if (_root && item.kind == CatalogueKind.series) {
      context.push('/downloads/series/${Uri.encodeComponent(item.id)}');
    } else {
      openBookReader(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(downloadedReadingSeriesProvider);

    return Scaffold(
      appBar: InkScreenHeader(
        title: LText(_root ? 'Downloads' : 'Downloaded volumes'),
        actions: [
          InkHeaderSearch(
            key: const Key('downloads-search'),
            controller: _search,
            hint: _root ? 'Search' : 'Search downloaded volumes',
            onChanged: _searchChanged,
            onClear: _clearSearch,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          child: series.when(
            loading: () => const SingleChildScrollView(
              child: InkSkeletonList(key: Key('downloads-skeleton')),
            ),
            error: (_, _) => InkEmptyState(
              icon: InkIcons.warningCircle,
              title: 'Offline shelf unavailable',
              message: 'Unable to open your downloaded books.',
              label: 'Retry',
              action: () {
                ref.invalidate(offlineCoordinatorProvider);
                ref.invalidate(downloadedReadingSeriesProvider);
              },
            ),
            data: (all) => _content(context, all),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<DownloadedSeries> all) {
    final root = _root;
    final parent = all
        .where(
          (group) =>
              group.item.kind == CatalogueKind.series &&
              group.item.id == widget.seriesId,
        )
        .firstOrNull;
    // Lowercase each title once and resolve rows through maps, so a
    // keystroke costs O(n log n) instead of O(n²) list scans.
    final term = _term;
    final titles = <String, String>{};
    String title(CatalogueItem item) =>
        titles[item.identity] ??= item.title.toLowerCase();
    final groups = {
      for (final group in all)
        if (title(group.item).contains(term) &&
            _matches(group.item, _metadataFilters))
          group.item.identity: group,
    };
    final volumes = {
      for (final book in parent?.books ?? const <DownloadedBook>[])
        if (title(book.item).contains(term) &&
            _matches(book.item, _metadataFilters))
          book.item.id: book,
    };
    final visible = root
        ? [for (final group in groups.values) group.item]
        : [for (final book in volumes.values) book.item];
    if (_sort != CatalogueSort.sequence) {
      visible.sort((a, b) {
        final order = title(a).compareTo(title(b));
        return _sort == CatalogueSort.titleDescending ? -order : order;
      });
    }
    DownloadedSeries groupFor(CatalogueItem item) => groups[item.identity]!;
    final grid =
        root && _grid && MediaQuery.textScalerOf(context).scale(1) <= 1.5;
    final seriesGroups = [
      if (root)
        for (final item in visible)
          if (item.kind == CatalogueKind.series) groupFor(item),
    ];
    final bookGroups = [
      if (root)
        for (final item in visible)
          if (item.kind != CatalogueKind.series) groupFor(item),
    ];
    Widget heading(String label) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpace.lg,
          InkSpace.lg,
          InkSpace.lg,
          InkSpace.xs,
        ),
        child: Semantics(
          header: true,
          child: LText(
            label,
            style: Theme.of(context).textTheme.sectionTitle
                ?.copyWith(color: InkoraColors.of(context).heading),
          ),
        ),
      ),
    );
    Widget rows(String key, List<DownloadedSeries> groups) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpace.lg),
      sliver: SliverList.builder(
        key: Key(key),
        itemCount: groups.length,
        itemBuilder: (_, index) => DownloadGroupRow(
          key: ValueKey('download-row-${groups[index].item.identity}'),
          group: groups[index],
          onOpen: _open,
          onRemoveDownload: widget.onRemoveDownload,
        ),
      ),
    );

    return CustomScrollView(
      controller: _scroll,
      scrollCacheExtent: const ScrollCacheExtent.viewport(1),
      slivers: [
        if (root) ...[const SliverToBoxAdapter(child: DownloadQueueCard())],
        PinnedHeaderSliver(
          child: ColoredBox(
            key: const Key('downloads-pinned-tools'),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: InkFilterBar(
              controlPrefix: 'downloads',
              startChipsWhenCompact: true,
              leading: Text(
                AppStrings.of(context)
                    .quantity(visible.length, root ? 'item' : 'book'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              // Everything here is downloaded: no Downloaded toggle.
              chips: readingFilterChips(
                filters: _metadataFilters,
                offline: true,
                onChanged: (filters) =>
                    _change(() => _metadataFilters = filters),
              ),
              sort: InkSortButton<CatalogueSort>(
                key: const Key('downloads-sort'),
                value: _sort,
                options: catalogueSortOptions(recent: false, sequence: !root),
                onSelected: (value) => setState(() => _sort = value),
              ),
              filterCount: _metadataFilters.values.length,
              onFilters: _filters,
              actions: [
                if (root)
                  IconButton(
                    key: const Key('downloads-view'),
                    tooltip: context.tr(_grid ? 'Show list' : 'Show grid'),
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(
                      _grid ? InkIcons.list : InkIcons.squaresFour,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: InkEmptyState(
              icon: InkIcons.downloadSimple,
              title: all.isEmpty
                  ? 'Your offline shelf is empty'
                  : 'No matching books',
              message: all.isEmpty
                  ? 'Download a volume using the button beside its name.'
                  : 'Try another title.',
              label: all.isEmpty ? 'Browse libraries' : null,
              action: all.isEmpty ? () => context.go('/libraries') : null,
            ),
          )
        else if (!root)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: InkSpace.lg),
            sliver: SliverList.builder(
              key: const Key('downloads-list'),
              itemCount: visible.length,
              itemBuilder: (_, index) {
                final book = volumes[visible[index].id]!;
                return VolumeRow(
                  key: ValueKey('download-volume-${book.item.id}'),
                  seriesId: widget.seriesId!,
                  seriesTitle: parent?.item.title ?? '',
                  volume: downloadedVolume(book, widget.seriesId!),
                  index: index,
                  current: false,
                  selecting: false,
                  controller: _browser,
                  actions: _actions,
                  onRemoveDownload: widget.onRemoveDownload,
                );
              },
            ),
          )
        else if (grid)
          CatalogueGrid(
            key: const Key('downloads-grid'),
            artwork: [for (final item in visible) groupFor(item).artwork],
            itemCount: visible.length,
            itemBuilder: (_, index) {
              final item = visible[index];
              final book = item.kind == CatalogueKind.book;
              return InkCoverTile(
                key: ValueKey('download-${item.identity}'),
                item: item,
                coverItem: groupFor(item).artwork,
                offlineBadge: false,
                openLabel: book ? 'Read offline' : null,
                downloadedJob: book ? groupFor(item).books.single.job : null,
                onRemoveDownload: widget.onRemoveDownload,
                onOpen: _open,
              );
            },
          )
        else ...[
          if (seriesGroups.isNotEmpty) ...[
            heading('Series'),
            rows('downloads-series', seriesGroups),
          ],
          if (bookGroups.isNotEmpty) ...[
            heading('Books'),
            rows('downloads-books', bookGroups),
          ],
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
        ),
      ],
    );
  }
}

/// A downloaded book as a series volume row input.
SeriesVolume downloadedVolume(DownloadedBook book, String seriesId) =>
    SeriesVolume(
      id: book.item.id,
      seriesId: book.item.seriesId ?? seriesId,
      title: book.item.title,
      libraryId: book.item.libraryId,
      number: book.item.number,
      pageCount: book.item.pageCount,
      modified: book.item.modified,
      mediaType: book.item.metadata.mediaType,
      serverStatus: book.item.readingStatus,
    );

/// One downloaded series or individual book in the Downloads list: 40-px
/// cover, title, "3 volumes · 412 MiB · 1/3 read". Tap opens the series'
/// downloaded volumes (or reads the book offline); long press opens a menu
/// (also exposed as custom semantics actions) with removal, confirmed first.
/// Books keep the shared trailing remove action.
class DownloadGroupRow extends ConsumerWidget {
  const DownloadGroupRow({
    super.key,
    required this.group,
    required this.onOpen,
    this.onRemoveDownload,
  });
  final DownloadedSeries group;
  final ValueChanged<CatalogueItem> onOpen;
  final Future<void> Function(String jobId)? onRemoveDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final item = group.item;
    final series = item.kind == CatalogueKind.series;
    final summary = downloadGroupSummary(context, group);
    final menu = <(String, IconData, VoidCallback)>[
      (
        series ? 'Open series' : 'Read offline',
        series ? InkIcons.books : InkIcons.bookOpen,
        () => onOpen(item),
      ),
      (
        series ? 'Remove downloads' : 'Remove download',
        InkIcons.trash,
        () => removeDownloadedGroup(
          context,
          ref,
          group,
          onRemoveDownload: onRemoveDownload,
        ),
      ),
    ];
    Offset? pressed;
    Future<void> showActions() async {
      final overlay =
          Overlay.of(context).context.findRenderObject()! as RenderBox;
      final box = context.findRenderObject() as RenderBox?;
      final anchor =
          pressed ??
          (box == null
              ? overlay.size.center(Offset.zero)
              : box.localToGlobal(box.size.center(Offset.zero)));
      final selected = await showMenu<VoidCallback>(
        context: context,
        position: RelativeRect.fromRect(
          anchor & Size.zero,
          Offset.zero & overlay.size,
        ),
        items: [
          for (final (label, icon, run) in menu)
            PopupMenuItem(
              value: run,
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: InkSpace.md),
                  Flexible(child: LText(label)),
                ],
              ),
            ),
        ],
      );
      selected?.call();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .25)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              label: '${item.title}, $summary',
              customSemanticsActions: {
                for (final (label, _, run) in menu.skip(1))
                  CustomSemanticsAction(label: strings.text(label)): run,
              },
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onOpen(item),
                onTapDown: (details) => pressed = details.globalPosition,
                onLongPress: showActions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: InkSpace.sm),
                  child: Row(
                    children: [
                      BookCover(item: group.artwork, width: 40),
                      const SizedBox(width: InkSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: volumeTitleStyle(theme),
                            ),
                            Text(
                              summary,
                              style: theme.textTheme.meta?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (series)
            const ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.all(InkSpace.md),
                child: Icon(InkIcons.caretRight, size: 20),
              ),
            )
          else
            DownloadBookAction(
              bookId: item.id,
              title: item.title,
              completedJob: group.books.single.job,
              onRemoveDownload: onRemoveDownload,
            ),
        ],
      ),
    );
  }
}
