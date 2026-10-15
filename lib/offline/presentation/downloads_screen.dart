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
  bool _listView = false;

  @override
  void dispose() {
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
    final series = ref.watch(downloadedSeriesProvider);
    final density =
        ref.watch(
          uiPreferencesProvider.select((value) => value.asData?.value.density),
        ) ??
        CatalogueDensity.comfortable;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Scaffold(
      appBar: widget.seriesId == null
          ? null
          : AppBar(title: const LText('Downloaded volumes')),
      body: SafeArea(
        top: false,
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
              final term = _search.text.trim().toLowerCase();
              final titles = <String, String>{};
              String title(CatalogueItem item) =>
                  titles[item.identity] ??= item.title.toLowerCase();
              final groups = {
                for (final group in all)
                  if (title(group.item).contains(term))
                    group.item.identity: group,
              };
              final volumes = {
                for (final book in parent?.books ?? const <DownloadedBook>[])
                  if (title(book.item).contains(term)) book.item.id: book,
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: LText(
                                  root
                                      ? 'Downloads'
                                      : parent?.item.title ??
                                            'Downloaded volumes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ),
                              if (root)
                                IconButton(
                                  tooltip: context.tr('Download queue'),
                                  icon: const Icon(InkIcons.list),
                                  onPressed: () =>
                                      context.push('/downloads/queue'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('downloads-search'),
                            controller: _search,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                root ? 'Search' : 'Search downloaded volumes',
                              ),
                              prefixIcon: const Icon(InkIcons.magnifyingGlass),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: context.tr("Clear search"),
                                      onPressed: () => _change(_search.clear),
                                      icon: const Icon(InkIcons.x),
                                    ),
                            ),
                            onChanged: (_) => _change(() {}),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                AppStrings.of(context).quantity(
                                  visible.length,
                                  root ? 'item' : 'book',
                                ),
                              ),
                              SizedBox(
                                width: scale > 1.3 ? double.infinity : 160,
                                child: DropdownButton<CatalogueSort>(
                                  icon: const Icon(
                                    InkIcons.caretDown,
                                    size: 20,
                                  ),
                                  isExpanded: true,
                                  itemHeight: null,
                                  key: const Key('downloads-sort'),
                                  value: _sort,
                                  items: [
                                    const DropdownMenuItem(
                                      value: CatalogueSort.title,
                                      child: LText(
                                        'Title A–Z',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const DropdownMenuItem(
                                      value: CatalogueSort.titleDescending,
                                      child: LText(
                                        'Title Z–A',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!root)
                                      const DropdownMenuItem(
                                        value: CatalogueSort.sequence,
                                        child: LText('Book number'),
                                      ),
                                  ],
                                  onChanged: (sort) {
                                    if (sort != null) {
                                      _change(() => _sort = sort);
                                    }
                                  },
                                ),
                              ),
                              if (root)
                                IconButton(
                                  tooltip: context.tr(
                                    _listView ? 'Show grid' : 'Show list',
                                  ),
                                  onPressed: () =>
                                      setState(() => _listView = !_listView),
                                  icon: Icon(
                                    _listView
                                        ? InkIcons.squaresFour
                                        : InkIcons.list,
                                  ),
                                ),
                            ],
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
