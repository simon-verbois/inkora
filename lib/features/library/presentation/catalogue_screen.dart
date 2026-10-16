import 'catalogue_toolbar.dart';
import '../domain/catalogue_filters.dart';
import 'catalogue_filters_sheet.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/inkora_widgets.dart';
import '../../settings/application/ui_preferences_provider.dart';
import '../../settings/domain/ui_preferences.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue.dart';
import 'catalogue_card.dart';
import 'catalogue_grid.dart';
import 'catalogue_widgets.dart';
import 'volume_list_tile.dart';
import 'volume_list.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({
    required this.kind,
    this.libraryId,
    this.seriesId,
    this.groupKind,
    this.groupId,
    this.ordered = false,
    this.embedded = false,
    this.searchMode = false,
    this.initialSort,
    super.key,
  });
  final CatalogueKind kind;
  final String? libraryId, seriesId, groupId;
  final CatalogueKind? groupKind;
  final bool ordered, embedded, searchMode;
  final CatalogueSort? initialSort;
  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late CatalogueSort _sort;
  late CatalogueKind _kind;
  String? _libraryId;
  String _searchQuery = '';
  bool _showUnavailable = true, _listView = false;
  MetadataFilters _metadataFilters = const MetadataFilters();
  late bool _searchOpen;

  CatalogueQuery get _query => CatalogueQuery(
    kind: _kind,
    readingUnits: _kind == CatalogueKind.series,
    libraryId: _kind == CatalogueKind.book || _kind == CatalogueKind.series
        ? _libraryId
        : null,
    seriesId: widget.seriesId,
    groupKind: widget.groupKind,
    groupId: widget.groupId,
    search: _searchQuery,
    sort: _sort,
    showUnavailable: _showUnavailable,
    filters: _metadataFilters,
  );

  @override
  void initState() {
    super.initState();
    _reset();
    _scroll.addListener(_more);
  }

  void _reset() {
    _metadataFilters = const MetadataFilters();
    _kind = widget.embedded ? CatalogueKind.series : widget.kind;
    _libraryId = widget.libraryId;
    _sort =
        widget.initialSort ??
        (widget.ordered || widget.seriesId != null
            ? CatalogueSort.sequence
            : CatalogueSort.title);
    _searchOpen = widget.searchMode;
    _searchQuery = '';
    _searchWasEmpty = true;
    _search.clear();
  }

  @override
  void didUpdateWidget(CatalogueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.libraryId != widget.libraryId ||
        oldWidget.seriesId != widget.seriesId ||
        oldWidget.groupId != widget.groupId) {
      _debounce?.cancel();
      _reset();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _more() {
    if (!mounted ||
        !_scroll.hasClients ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension * 2) {
      ref.read(catalogueFeedProvider(_query)).asData?.value?.loadMore();
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
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _searchWasEmpty = true;
  void _searchChanged(String value) {
    // Only the clear button depends on the raw text; rebuild the screen (and
    // its grid) when it appears/disappears, not on every keystroke.
    if (value.isEmpty != _searchWasEmpty) {
      setState(() => _searchWasEmpty = value.isEmpty);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _change(() => _searchQuery = value);
    });
  }

  Future<void> _selectLibrary() async {
    final result = await showInkSheet<(String?,)>(
      context: context,
      child: _LibrarySelector(selected: _libraryId),
    );
    if (!mounted || result == null) return;
    _change(() {
      _libraryId = result.$1;
      _metadataFilters = const MetadataFilters();
      if (_kind != CatalogueKind.book && _kind != CatalogueKind.series) {
        _kind = CatalogueKind.series;
      }
    });
  }

  Future<void> _filters() async {
    final query = _query;
    final options = ref
        .read(catalogueRepositoryProvider.future)
        .then(
          (repository) =>
              repository?.store.facets(query) ??
              Future.value(<CatalogueFacet, List<String>>{}),
        );
    final result = await showInkSheet<CatalogueFilterResult>(
      context: context,
      child: CatalogueFiltersSheet(
        showUnavailable: _showUnavailable,
        filters: _metadataFilters,
        options: options,
      ),
    );
    if (!mounted || result == null) return;
    _change(() {
      _showUnavailable = result.showUnavailable;
      _metadataFilters = result.filters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final data = ref.watch(catalogueFeedStateProvider(query));
    ref.listen(catalogueFeedStateProvider(query), (_, next) {
      if (next.asData?.value.loading == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _more();
          }
        });
      }
    });
    final state = data.asData?.value;
    final page = state?.page;
    final items = page?.items ?? const <CatalogueItem>[];
    final libraries =
        ref
            .watch(
              cataloguePageProvider(
                const CatalogueQuery(
                  kind: CatalogueKind.library,
                  pageSize: 200,
                  showUnavailable: false,
                ),
              ),
            )
            .asData
            ?.value
            .items ??
        [];
    final selectedLibrary = libraries
        .where((item) => item.id == _libraryId)
        .firstOrNull;
    final density =
        ref.watch(
          uiPreferencesProvider.select((value) => value.asData?.value.density),
        ) ??
        CatalogueDensity.comfortable;
    final volumesOnly =
        _kind == CatalogueKind.book && !items.any((item) => item.isEbook);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final categories = widget.searchMode;
    final librarySelection = widget.seriesId == null && widget.groupId == null;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: LText(
                widget.searchMode
                    ? 'Search'
                    : _kind == CatalogueKind.series
                    ? 'Books'
                    : catalogueLabel(_kind),
              ),
            ),
      body: SafeArea(
        top: false,
        child: InkContent(
          child: Builder(
            builder: (context) => RefreshIndicator(
              onRefresh: () => refreshCatalogue(ref),
              child: CustomScrollView(
                controller: _scroll,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const CatalogueRefreshStatus(),
                        CatalogueToolbar(
                          controlPrefix: 'catalogue',
                          searchOpen: _searchOpen,
                          onSearch: () =>
                              setState(() => _searchOpen = !_searchOpen),
                          onFilters: _filters,
                          filtered: !_metadataFilters.isEmpty,
                          listView: _kind != CatalogueKind.book
                              ? _listView
                              : null,
                          onView: () => setState(() => _listView = !_listView),
                          sort: categories
                              ? const SizedBox.shrink()
                              : _sortButton(),
                          leading: librarySelection
                              ? TextButton(
                                  key: const Key('library-selector'),
                                  onPressed: _selectLibrary,
                                  style: TextButton.styleFrom(
                                    foregroundColor: colors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(InkIcons.books, size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          selectedLibrary?.title ??
                                              context.tr(
                                                _libraryId == null
                                                    ? 'All libraries'
                                                    : 'Selected library',
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(InkIcons.caretDown, size: 16),
                                    ],
                                  ),
                                )
                              : Text(
                                  AppStrings.of(context)
                                      .quantity(page?.total ?? 0, 'item'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                        ),
                        if (_searchOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: TextField(
                              key: const Key('catalogue-search'),
                              controller: _search,
                              autofocus: widget.searchMode,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.tr("Search saved catalogue"),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIcon: const Icon(
                                  InkIcons.magnifyingGlass,
                                  size: 18,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: context.tr("Clear search"),
                                        icon: const Icon(InkIcons.x, size: 18),
                                        onPressed: () {
                                          _debounce?.cancel();
                                          _change(() {
                                            _search.clear();
                                            _searchWasEmpty = true;
                                            _searchQuery = '';
                                          });
                                        },
                                      ),
                              ),
                              onChanged: _searchChanged,
                            ),
                          ),
                        if (categories)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48 * scale.clamp(1, 1.5),
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    children: [
                                      for (final kind in [
                                        CatalogueKind.series,
                                        CatalogueKind.collection,
                                        CatalogueKind.readlist,
                                        CatalogueKind.library,
                                      ])
                                        Semantics(
                                          selected: _kind == kind,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: _kind == kind
                                                      ? colors.primary
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                            child: TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: _kind == kind
                                                    ? colors.primary
                                                    : colors.onSurfaceVariant,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                minimumSize: const Size(0, 48),
                                              ),
                                              onPressed: () => _change(() {
                                                _kind = kind;
                                                _metadataFilters =
                                                    const MetadataFilters();
                                                _sort = CatalogueSort.title;
                                              }),
                                              child: LText(
                                                kind == CatalogueKind.series
                                                    ? 'Books'
                                                    : catalogueLabel(kind),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              _sortButton(),
                              const SizedBox(width: 8),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (items.isNotEmpty)
                    if (_listView ||
                        volumesOnly ||
                        _kind == CatalogueKind.library ||
                        scale > 1.5)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: volumesOnly
                            ? VolumeList(
                                key: const Key('catalogue-list'),
                                itemCount: items.length,
                                itemBuilder: (_, index) =>
                                    VolumeListTile(item: items[index]),
                              )
                            : SliverList.separated(
                                key: const Key('catalogue-list'),
                                itemCount: items.length,
                                itemBuilder: (_, index) => volumesOnly
                                    ? VolumeListTile(item: items[index])
                                    : CatalogueItemTile(item: items[index]),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                              ),
                      )
                    else
                      CatalogueGrid(
                        key: const Key('catalogue-grid'),
                        density: density,
                        itemCount: items.length,
                        artwork: items,
                        itemBuilder: (_, index) =>
                            CatalogueCard(item: items[index]),
                      )
                  else if (data.isLoading || state?.loading == true)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: InkEmptyState(
                        icon: data.hasError || state?.error == true
                            ? InkIcons.cloudSlash
                            : InkIcons.magnifyingGlassMinus,
                        title: data.hasError || state?.error == true
                            ? 'Catalogue unavailable'
                            : query.search.isNotEmpty
                            ? 'No matching books'
                            : 'Nothing here yet',
                        message: page?.lastUpdated == null
                            ? 'Connect and refresh to browse your catalogue offline.'
                            : 'Try another library, category or search.',
                      ),
                    ),
                  if (items.isNotEmpty &&
                      (state?.loading == true || state?.hasMore == true))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: state?.error == true
                              ? TextButton(
                                  onPressed: () => ref
                                      .read(catalogueFeedProvider(query))
                                      .asData
                                      ?.value
                                      ?.retry(),
                                  child: const LText('Retry loading books'),
                                )
                              : state?.loading == true
                              ? const LinearProgressIndicator()
                              : const SizedBox(height: 24),
                        ),
                      ),
                    ),
                  if (items.isNotEmpty && state?.hasMore == false)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Text(
                          AppStrings.of(context).quantity(page!.total, 'item'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortButton() => PopupMenuButton<CatalogueSort>(
    key: const Key('catalogue-sort'),
    tooltip: context.tr("Sort catalogue"),
    initialValue: _sort,
    icon: const Icon(InkIcons.sortAscending, size: 20),
    onSelected: (sort) => _change(() => _sort = sort),
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: CatalogueSort.title,
        child: LText('Title A–Z'),
      ),
      const PopupMenuItem(
        value: CatalogueSort.titleDescending,
        child: LText('Title Z–A'),
      ),
      const PopupMenuItem(
        value: CatalogueSort.recentlyUpdated,
        child: LText('Recently updated'),
      ),
      if (widget.groupId != null || widget.seriesId != null)
        PopupMenuItem(
          value: CatalogueSort.sequence,
          child: LText(widget.groupId != null ? 'List order' : 'Book number'),
        ),
    ],
  );
}

class _LibrarySelector extends ConsumerWidget {
  const _LibrarySelector({required this.selected});
  final String? selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      cataloguePageProvider(
        const CatalogueQuery(
          kind: CatalogueKind.library,
          pageSize: 200,
          showUnavailable: false,
        ),
      ),
    );
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        LText(
          'Choose a library',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const LText('All libraries'),
          leading: const Icon(InkIcons.books),
          trailing: selected == null ? const Icon(InkIcons.check) : null,
          onTap: () => Navigator.pop(context, (null,)),
        ),
        ...data.when(
          loading: () => [const LinearProgressIndicator()],
          error: (_, _) => [const LText('Saved libraries unavailable.')],
          data: (page) => [
            for (final library in page.items)
              ListTile(
                title: Text(library.title),
                leading: const Icon(InkIcons.books),
                trailing: library.id == selected
                    ? const Icon(InkIcons.check)
                    : null,
                onTap: () => Navigator.pop(context, (library.id,)),
              ),
          ],
        ),
      ],
    );
  }
}
