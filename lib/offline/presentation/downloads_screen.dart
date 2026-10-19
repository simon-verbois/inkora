import '../../features/library/presentation/reading_filter_chips.dart';
import '../../../app/widgets/ink_surface.dart';

import 'dart:async';

import '../../features/library/domain/catalogue_filters.dart';
import '../../features/library/presentation/catalogue_filters_sheet.dart';
import '../../features/library/presentation/catalogue_toolbar.dart';
import 'inline_download_queue.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/catalogue_card.dart';
import '../../features/library/presentation/catalogue_grid.dart';
import '../../features/library/presentation/catalogue_widgets.dart';
import '../../features/library/presentation/volume_list_tile.dart';
import '../../features/library/presentation/volume_list.dart';
import '../../features/settings/application/ui_preferences_provider.dart';
import '../../features/settings/domain/ui_preferences.dart';
import '../application/offline_coordinator.dart';
import '../data/download_store.dart';
import 'download_book_action.dart';

/// Ebook books and comic series share the root offline shelf.
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
  late CatalogueSort _sort = widget.seriesId == null
      ? CatalogueSort.title
      : CatalogueSort.sequence;
  bool _listView = false, _searchOpen = false, _searchWasEmpty = true;
  String _term = '';
  Timer? _debounce;
  MetadataFilters _metadataFilters = const MetadataFilters();

  void _searchChanged(String value) {
    if (value.isEmpty != _searchWasEmpty) {
      setState(() => _searchWasEmpty = value.isEmpty);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _change(() => _term = value.trim().toLowerCase());
    });
  }

  Future<void> _filters() async {
    final all = ref.read(downloadedSeriesProvider).asData?.value ?? [];
    final items = widget.seriesId == null
        ? all.map((group) => group.item)
        : all
              .where((group) => group.item.id == widget.seriesId)
              .expand((group) => group.books.map((book) => book.item));
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
    final result = await showInkSheet<CatalogueFilterResult>(
      context: context,
      child: CatalogueFiltersSheet(
        downloadOptions: false,
        options: Future.value(options),
        filters: _metadataFilters,
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
    super.dispose();
  }

  void _change(VoidCallback change) {
    setState(() {
      change();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _read(CatalogueItem item) => openCatalogueItem(context, item);

  @override
  Widget build(BuildContext context) {
    final series = _metadataFilters.readingStatus == ReadingStatus.any
        ? ref.watch(downloadedSeriesProvider)
        : ref.watch(downloadedReadingSeriesProvider);
    final density =
        ref.watch(
          uiPreferencesProvider.select((value) => value.asData?.value.density),
        ) ??
        CatalogueDensity.comfortable;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: widget.seriesId == null
          ? null
          : InkAppBar(title: const LText('Downloaded volumes')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          child: series.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => InkEmptyState(
              icon: InkIcons.warningCircle,
              title: context.tr("Offline shelf unavailable"),
              message: context.tr("Unable to open your downloaded books."),
              label: context.tr("Retry"),
              action: () {
                ref.invalidate(offlineCoordinatorProvider);
                ref.invalidate(downloadedBooksProvider);
              },
            ),
            data: (all) {
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
                      _metadataFilters.matches(group.item.metadata) &&
                      (_metadataFilters.readingStatus == ReadingStatus.any ||
                          group.item.readingStatus ==
                              _metadataFilters.readingStatus))
                    group.item.identity: group,
              };
              final volumes = {
                for (final book in parent?.books ?? const <DownloadedBook>[])
                  if (title(book.item).contains(term) &&
                      _metadataFilters.matches(book.item.metadata) &&
                      (_metadataFilters.readingStatus == ReadingStatus.any ||
                          book.item.readingStatus ==
                              _metadataFilters.readingStatus))
                    book.item.id: book,
              };
              final root = widget.seriesId == null;
              final visible = root
                  ? [for (final group in groups.values) group.item]
                  : [for (final book in volumes.values) book.item];
              if (_sort != CatalogueSort.sequence) {
                visible.sort((a, b) {
                  final order = title(a).compareTo(title(b));
                  return _sort == CatalogueSort.titleDescending
                      ? -order
                      : order;
                });
              }
              DownloadedSeries groupFor(CatalogueItem item) =>
                  groups[item.identity]!;
              DownloadedBook bookFor(CatalogueItem item) => volumes[item.id]!;
              CatalogueItem artwork(CatalogueItem item) =>
                  root ? groupFor(item).artwork : item;
              Widget? removal(CatalogueItem item) =>
                  root && item.kind == CatalogueKind.book
                  ? DownloadBookAction(
                      bookId: item.id,
                      title: item.title,
                      completedJob: groupFor(item).books.single.job,
                      onRemoveDownload: widget.onRemoveDownload,
                    )
                  : null;
              void open(CatalogueItem item) {
                if (root && item.kind == CatalogueKind.series) {
                  context.push(
                    '/downloads/series/${Uri.encodeComponent(item.id)}',
                  );
                } else {
                  _read(item);
                }
              }

              return CustomScrollView(
                controller: _scroll,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CatalogueToolbar(
                          quickFilters: (compact) => ReadingFilterChips(
                            compact: compact,
                            filters: _metadataFilters,
                            offline: true,
                            onChanged: (filters) =>
                                _change(() => _metadataFilters = filters),
                          ),
                          controlPrefix: 'downloads',
                          leading: Text(
                            AppStrings.of(
                              context,
                            ).quantity(visible.length, root ? 'item' : 'book'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          searchOpen: _searchOpen,
                          onSearch: () =>
                              setState(() => _searchOpen = !_searchOpen),
                          onFilters: _filters,
                          filtered: !_metadataFilters.isEmpty,
                          listView: root ? _listView : null,
                          onView: () => setState(() => _listView = !_listView),
                          sort: PopupMenuButton<CatalogueSort>(
                            key: const Key('downloads-sort'),
                            tooltip: context.tr('Sort catalogue'),
                            initialValue: _sort,
                            icon: const Icon(InkIcons.sortAscending, size: 20),
                            onSelected: (value) =>
                                setState(() => _sort = value),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: CatalogueSort.title,
                                child: LText('Title A–Z'),
                              ),
                              const PopupMenuItem(
                                value: CatalogueSort.titleDescending,
                                child: LText('Title Z–A'),
                              ),
                              if (!root)
                                const PopupMenuItem(
                                  value: CatalogueSort.sequence,
                                  child: LText('Book number'),
                                ),
                            ],
                          ),
                        ),
                        if (_searchOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: TextField(
                              key: const Key('downloads-search'),
                              controller: _search,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.tr(
                                  root ? 'Search' : 'Search downloaded volumes',
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(
                                  InkIcons.magnifyingGlass,
                                  size: 18,
                                ),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: context.tr('Clear search'),
                                        icon: const Icon(InkIcons.x, size: 18),
                                        onPressed: () {
                                          _debounce?.cancel();
                                          _change(() {
                                            _search.clear();
                                            _term = '';
                                            _searchWasEmpty = true;
                                          });
                                        },
                                      ),
                              ),
                              onChanged: _searchChanged,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (root) InlineDownloadQueue(search: _term),
                  if (visible.isEmpty)
                    SliverToBoxAdapter(
                      child: InkEmptyState(
                        icon: InkIcons.downloadSimple,
                        title: all.isEmpty
                            ? 'Your offline shelf is empty'
                            : root
                            ? 'No matching books'
                            : 'No matching books',
                        message: all.isEmpty
                            ? 'Download a volume using the button beside its name.'
                            : 'Try another title.',
                        label: all.isEmpty ? 'Browse libraries' : null,
                        action: all.isEmpty
                            ? () => context.go('/libraries')
                            : null,
                      ),
                    )
                  else if (!root || _listView || scale > 1.5)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: !root
                          ? VolumeList(
                              key: const Key('downloads-list'),
                              itemCount: visible.length,
                              itemBuilder: (_, index) => VolumeListTile(
                                item: visible[index],
                                onOpen: open,
                                completedJob: bookFor(visible[index]).job,
                                onRemoveDownload: widget.onRemoveDownload,
                              ),
                            )
                          : SliverList.separated(
                              key: const Key('downloads-list'),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) => root
                                  ? CatalogueItemTile(
                                      item: visible[index],
                                      coverItem: artwork(visible[index]),
                                      trailing: removal(visible[index]),
                                      onOpen: open,
                                    )
                                  : VolumeListTile(
                                      item: visible[index],
                                      onOpen: open,
                                      completedJob: bookFor(visible[index]).job,
                                      onRemoveDownload: widget.onRemoveDownload,
                                    ),
                            ),
                    )
                  else
                    CatalogueGrid(
                      key: const Key('downloads-grid'),
                      density: density,
                      artwork: [for (final item in visible) artwork(item)],
                      itemCount: visible.length,
                      itemBuilder: (_, index) => CatalogueCard(
                        key: ValueKey('download-${visible[index].identity}'),
                        item: visible[index],
                        coverItem: artwork(visible[index]),
                        showMenu: !root,
                        coverAction: removal(visible[index]),
                        onOpen: open,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
