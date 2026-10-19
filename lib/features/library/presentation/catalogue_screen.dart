import 'reading_filter_chips.dart';
import '../../connection/application/session_controller.dart';
import '../../../app/widgets/ink_surface.dart';
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
    this.initialSort,
    this.header,
    super.key,
  });
  final CatalogueKind kind;
  final String? libraryId, seriesId, groupId;
  final CatalogueKind? groupKind;
  final bool ordered, embedded;
  final CatalogueSort? initialSort;
  final Widget? header;
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
  int _initialWindowSize = 60;
  LocalCataloguePage? _sortingPage;
  String? _sortingAccount;
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
    initialWindowSize: _initialWindowSize,
  );

  @override
  void initState() {
    super.initState();
    _reset();
    _scroll.addListener(_more);
  }

  void _reset() {
    _metadataFilters = const MetadataFilters();
    _initialWindowSize = 60;
    _sortingPage = null;
    _kind = widget.embedded ? CatalogueKind.series : widget.kind;
    _libraryId = widget.libraryId;
    _sort =
        widget.initialSort ??
        (widget.ordered || widget.seriesId != null
            ? CatalogueSort.sequence
            : CatalogueSort.title);
    _searchOpen = false;
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
    setState(() {
      _sortingPage = null;
      _initialWindowSize = 60;
      change();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _sortChanged(CatalogueSort sort) {
    if (sort == _sort) return;
    final state = ref.read(catalogueFeedStateProvider(_query)).asData?.value;
    final current = state != null && !state.loading && !state.error
        ? state.page
        : null;
    setState(() {
      _sortingPage = current ?? _sortingPage;
      _sortingAccount = ref.read(sessionProvider).session?.accountId;
      _initialWindowSize = _sortingPage?.items.length ?? 60;
      _sort = sort;
    });
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
      final query = value.trim();
      if (mounted && query != _searchQuery) _change(() => _searchQuery = query);
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
        readingOptions:
            _kind == CatalogueKind.book || _kind == CatalogueKind.series,
        downloadOptions:
            _kind == CatalogueKind.book || _kind == CatalogueKind.series,
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
    final account = ref.watch(
      sessionProvider.select((state) => state.session?.accountId),
    );
    if (_sortingAccount != account) _sortingPage = null;
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
    if (state != null && !state.loading && !state.error) _sortingPage = null;
    final page = _sortingPage ?? state?.page;
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
    final librarySelection = widget.seriesId == null && widget.groupId == null;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : InkAppBar(
              title: LText(
                _kind == CatalogueKind.series ? 'Books' : catalogueLabel(_kind),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          child: RefreshIndicator(
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
                      if (widget.header != null) widget.header!,
                    ],
                  ),
                ),
                PinnedHeaderSliver(
                  child: ColoredBox(
                    key: const Key('catalogue-pinned-tools'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        CatalogueToolbar(
                          controlPrefix: 'catalogue',
                          quickFilters:
                              _kind == CatalogueKind.book ||
                                  _kind == CatalogueKind.series
                              ? (compact) => ReadingFilterChips(
                                  compact: compact,
                                  filters: _metadataFilters,
                                  onChanged: (filters) =>
                                      _change(() => _metadataFilters = filters),
                                )
                              : null,
                          searchOpen: _searchOpen,
                          onSearch: () =>
                              setState(() => _searchOpen = !_searchOpen),
                          onFilters: _filters,
                          filtered: !_metadataFilters.isEmpty,
                          listView: _kind != CatalogueKind.book
                              ? _listView
                              : null,
                          onView: () => setState(() => _listView = !_listView),
                          sort: _sortButton(),
                          leading: librarySelection
                              ? _libraryButton(selectedLibrary)
                              : Text(
                                  AppStrings.of(context)
                                      .quantity(page?.total ?? 0, 'item'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                        ),
                        if (_searchOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: _searchField(),
                          ),
                      ],
                    ),
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
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _libraryButton(CatalogueItem? library) {
    final label =
        library?.title ??
        context.tr(_libraryId == null ? 'All libraries' : 'Selected library');
    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return Tooltip(
      message: label,
      child: TextButton(
        key: const Key('library-selector'),
        onPressed: _selectLibrary,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 48),
          fixedSize: compact ? const Size(48, 48) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(InkIcons.books, size: 18),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 6),
            const Icon(InkIcons.caretDown, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
    key: const Key('catalogue-search'),
    controller: _search,
    decoration: InputDecoration(
      isDense: true,
      hintText: context.tr("Search saved catalogue"),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      prefixIcon: const Icon(InkIcons.magnifyingGlass, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
  );

  Widget _sortButton() => PopupMenuButton<CatalogueSort>(
    key: const Key('catalogue-sort'),
    tooltip: context.tr("Sort catalogue"),
    initialValue: _sort,
    icon: const Icon(InkIcons.sortAscending, size: 20),
    onSelected: _sortChanged,
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
