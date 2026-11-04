import '../../../app/theme/inkora_theme.dart';
import '../../../app/theme/inkora_motion.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/ink_filter_bar.dart';
import 'reading_filter_chips.dart';
import '../../connection/application/session_controller.dart';
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
import '../data/saved_search_store.dart';
import '../domain/saved_catalogue_search.dart';
import 'saved_searches_sheet.dart';

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
    this.initialFilters = const MetadataFilters(),
    this.header,
    this.headerActions = const [],
    this.topInset = 0,
    super.key,
  });
  final CatalogueKind kind;
  final String? libraryId, seriesId, groupId;
  final CatalogueKind? groupKind;
  final bool ordered, embedded;
  final CatalogueSort? initialSort;

  /// Filters applied on open (a series page genre chip opens the catalogue
  /// filtered by that genre).
  final MetadataFilters initialFilters;
  final Widget? header;
  final List<Widget> headerActions;

  /// Space above the first content reserved for an overlaying header
  /// (Home's [InkHomeHeader]); the refresh indicator starts below it too.
  final double topInset;
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
  String? _seriesId, _groupId;
  CatalogueKind? _groupKind;
  String _searchQuery = '';
  int _initialWindowSize = 60;
  LocalCataloguePage? _sortingPage;
  String? _sortingAccount;
  String? _queryAccount;
  double? _filterMinimumExtent;
  double? _tailHeight;
  Widget? _tailSliver;
  bool _showUnavailable = false, _listView = false;
  MetadataFilters _metadataFilters = const MetadataFilters();

  CatalogueQuery get _query => CatalogueQuery(
    kind: _kind,
    readingUnits: _kind == CatalogueKind.series,
    libraryId: _kind == CatalogueKind.book || _kind == CatalogueKind.series
        ? _libraryId
        : null,
    seriesId: _seriesId,
    groupKind: _groupKind,
    groupId: _groupId,
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
    _filterMinimumExtent = null;
    _metadataFilters = widget.initialFilters;
    _initialWindowSize = 60;
    _sortingPage = null;
    _kind = widget.embedded ? CatalogueKind.series : widget.kind;
    _libraryId = widget.libraryId;
    _seriesId = widget.seriesId;
    _groupId = widget.groupId;
    _groupKind = widget.groupKind;
    _sort =
        widget.initialSort ??
        (widget.ordered || widget.seriesId != null
            ? CatalogueSort.sequence
            : CatalogueSort.title);
    _searchQuery = '';
    _search.clear();
    _showUnavailable = false;
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
    _filterMinimumExtent = null;
    setState(() {
      _sortingPage = null;
      _initialWindowSize = 60;
      change();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _quickFilters(
    MetadataFilters filters, {
    bool? showUnavailable,
    CatalogueSort? sort,
    bool? listView,
  }) {
    final current = ref.read(catalogueFeedStateProvider(_query)).asData?.value;
    setState(() {
      _sortingPage = current?.page ?? _sortingPage;
      _sortingAccount = ref.read(sessionProvider).session?.accountId;
      _initialWindowSize = _sortingPage?.items.length ?? 60;
      if (widget.embedded && _scroll.hasClients) {
        _filterMinimumExtent =
            _scroll.offset + _scroll.position.viewportDimension;
      }
      _metadataFilters = filters;
      _showUnavailable = showUnavailable ?? _showUnavailable;
      _sort = sort ?? _sort;
      _listView = listView ?? _listView;
    });
  }

  Widget _filterSpace(BuildContext context, SliverConstraints constraints) {
    final height =
        ((_filterMinimumExtent ?? 0) - constraints.precedingScrollExtent).clamp(
          0.0,
          double.infinity,
        );
    if (_tailSliver == null || _tailHeight != height) {
      _tailHeight = height;
      _tailSliver = SliverToBoxAdapter(child: SizedBox(height: height));
    }
    return _tailSliver!;
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

  /// Keystrokes never rebuild the screen: the field owns its clear button and
  /// the query changes once per 180-ms pause.
  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      final query = value.trim();
      if (mounted && query != _searchQuery) _change(() => _searchQuery = query);
    });
  }

  void _selectLibrary((String?,) result) {
    if (result.$1 == _libraryId) return;
    _change(() {
      _libraryId = result.$1;
      _metadataFilters = const MetadataFilters();
      if (_kind != CatalogueKind.book && _kind != CatalogueKind.series) {
        _kind = CatalogueKind.series;
      }
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    if (_searchQuery.isNotEmpty) _change(() => _searchQuery = '');
  }

  Future<void> _savedSearches() async {
    _debounce?.cancel();
    // Include the last typed characters even before the search debounce fires.
    if (_searchQuery != _search.text.trim()) {
      _change(() => _searchQuery = _search.text.trim());
    }
    final account = ref.read(sessionProvider).session?.accountId;
    if (account == null) return;
    final database = await ref.read(databaseProvider);
    bool current() =>
        mounted &&
        ref.read(sessionProvider).phase == SessionPhase.ready &&
        ref.read(sessionProvider).session?.accountId == account;
    if (!mounted || !current()) return;
    final saved = await showInkPopup<SavedCatalogueSearch>(
      context: context,
      child: SavedSearchesSheet(
        store: SavedSearchStore(database, account),
        query: _query,
        isCurrent: current,
      ),
    );
    if (saved == null || !current()) return;
    _change(() {
      final query = saved.query;
      _kind = query.kind;
      _libraryId = query.libraryId;
      _seriesId = query.seriesId;
      _groupId = query.groupId;
      _groupKind = query.groupKind;
      _sort = query.sort;
      _showUnavailable = query.showUnavailable;
      _metadataFilters = query.filters;
      _searchQuery = query.search;
      _search.text = query.search;
    });
  }

  Future<void> _filters() async {
    final query = _query;
    final repository = ref.read(catalogueRepositoryProvider.future);
    final options = repository.then(
      (repository) =>
          repository?.store.facets(query) ??
          Future.value(<CatalogueFacet, List<String>>{}),
    );
    // One indexed COUNT per settled draft (the sheet debounces changes).
    Future<int> count(MetadataFilters filters, bool showUnavailable) =>
        repository.then(
          (repository) =>
              repository?.store.count(
                CatalogueQuery(
                  kind: query.kind,
                  readingUnits: query.readingUnits,
                  libraryId: query.libraryId,
                  seriesId: query.seriesId,
                  groupKind: query.groupKind,
                  groupId: query.groupId,
                  search: query.search,
                  showUnavailable: showUnavailable,
                  filters: filters,
                ),
              ) ??
              Future.value(0),
        );
    var sort = _sort;
    var listView = _listView;
    var openSavedSearches = false;
    final result = await showInkPopup<CatalogueFilterResult>(
      context: context,
      child: CatalogueFiltersSheet(
        showUnavailable: _showUnavailable,
        filters: _metadataFilters,
        showReadingFilters: widget.embedded,
        options: options,
        count: count,
        catalogueControls: widget.embedded
            ? StatefulBuilder(
                builder: (panelContext, update) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkSortButton<CatalogueSort>(
                      key: const Key('catalogue-sort'),
                      value: sort,
                      options: catalogueSortOptions(),
                      onSelected: (value) => update(() => sort = value),
                    ),
                    IconButton(
                      key: const Key('catalogue-view'),
                      tooltip: panelContext.tr(
                        listView ? 'Show grid' : 'Show list',
                      ),
                      onPressed: () => update(() => listView = !listView),
                      icon: Icon(
                        listView ? InkIcons.squaresFour : InkIcons.list,
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('catalogue-saved-searches'),
                      onPressed: () {
                        openSavedSearches = true;
                        Navigator.pop(panelContext);
                      },
                      icon: const Icon(InkIcons.bookmarks),
                      label: const LText('Saved searches'),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
    if (!mounted) return;
    if (openSavedSearches) {
      await _savedSearches();
      return;
    }
    if (result == null) return;
    if (widget.embedded) {
      _quickFilters(
        result.filters,
        showUnavailable: result.showUnavailable,
        sort: sort,
        listView: listView,
      );
    } else {
      _change(() {
        _showUnavailable = result.showUnavailable;
        _metadataFilters = result.filters;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(
      sessionProvider.select((state) => state.session?.accountId),
    );
    if (_queryAccount != null && _queryAccount != account) {
      _debounce?.cancel();
      _reset();
    }
    _queryAccount = account;
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
    final libraries = ref.watch(
      cataloguePageProvider(
        const CatalogueQuery(
          kind: CatalogueKind.library,
          pageSize: 200,
          showUnavailable: false,
        ),
      ),
    );
    final selectedLibrary = libraries.asData?.value.items
        .where((item) => item.id == _libraryId)
        .firstOrNull;
    final window = MediaQuery.sizeOf(context);
    final homeColumns = widget.embedded
        ? ref.watch(
            uiPreferencesProvider.select(
              (value) => (value.asData?.value ?? const UiPreferences())
                  .homeColumnsFor(window.width, window.height),
            ),
          )
        : null;
    final volumesOnly =
        _kind == CatalogueKind.book && !items.any((item) => item.isEbook);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final cataloguePadding = EdgeInsets.fromLTRB(
      16,
      widget.embedded && window.width >= 840 && window.width > window.height
          ? 4
          : 16,
      16,
      16,
    );
    final librarySelection = _seriesId == null && _groupId == null;
    final search = InkHeaderSearch(
      key: const Key('catalogue-search'),
      controller: _search,
      hint: 'Search saved catalogue',
      actions: widget.headerActions,
      compact: widget.embedded && MediaQuery.sizeOf(context).width < 600,
      onChanged: _searchChanged,
      onClear: _clearSearch,
    );
    final tools = widget.embedded
        ? null
        : ColoredBox(
            key: const Key('catalogue-tools'),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: InkFilterBar(
              controlPrefix: 'catalogue',
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              leading: librarySelection
                  ? _libraryButton(selectedLibrary, libraries)
                  : Text(
                      AppStrings.of(context).quantity(page?.total ?? 0, 'item'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              chips:
                  _kind == CatalogueKind.book || _kind == CatalogueKind.series
                  ? readingFilterChips(
                      filters: _metadataFilters,
                      onChanged: _quickFilters,
                    )
                  : const [],
              sort: InkSortButton<CatalogueSort>(
                key: const Key('catalogue-sort'),
                value: _sort,
                options: catalogueSortOptions(
                  sequence: _groupId != null || _seriesId != null,
                  groupOrder: _groupId != null,
                ),
                onSelected: _sortChanged,
              ),
              filterCount: _metadataFilters.values.length,
              onFilters: _filters,
              actions: [
                IconButton(
                  key: const Key('catalogue-saved-searches'),
                  tooltip: context.tr('Saved searches'),
                  onPressed: _savedSearches,
                  icon: const Icon(InkIcons.bookmarks, size: 20),
                ),
                if (_kind != CatalogueKind.book)
                  IconButton(
                    key: const Key('catalogue-view'),
                    tooltip: context.tr(_listView ? 'Show grid' : 'Show list'),
                    onPressed: () => setState(() => _listView = !_listView),
                    icon: Icon(
                      _listView ? InkIcons.squaresFour : InkIcons.list,
                      size: 20,
                    ),
                  ),
              ],
            ),
          );
    final scaffold = Scaffold(
      floatingActionButton: widget.embedded
          ? Column(
              key: const Key('catalogue-floating-actions'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (librarySelection) ...[
                  _libraryButton(selectedLibrary, libraries, floating: true),
                  const SizedBox(height: 12),
                ],
                Badge(
                  isLabelVisible: !_metadataFilters.isEmpty,
                  child: _HomeAction(
                    key: const Key('catalogue-floating-filters'),
                    tooltip: context.tr('Filters'),
                    onPressed: _filters,
                    icon: InkIcons.slidersHorizontal,
                  ),
                ),
              ],
            )
          : null,
      appBar: widget.embedded
          ? null
          : InkScreenHeader(
              actions: [search],
              title: LText(
                _kind == CatalogueKind.series ? 'Books' : catalogueLabel(_kind),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          maxWidth: widget.embedded
              ? double.infinity
              : InkoraLayout.maxContentWidth,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.embedded && window.width >= 600
                  ? (window.width * .0125).clamp(8.0, 24.0)
                  : 0,
            ),
            child: RefreshIndicator(
              edgeOffset:
                  widget.topInset +
                  (widget.embedded ? InkScreenHeader.extent : 0),
              onRefresh: () => refreshCatalogue(ref),
              child: CustomScrollView(
                controller: _scroll,
                // Keep the fixed header and floating actions rigid during
                // overscroll; pull-to-refresh retains its existing owner.
                scrollBehavior: widget.embedded
                    ? ScrollConfiguration.of(context)
                          .copyWith(overscroll: false)
                    : null,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (widget.embedded)
                    const SliverToBoxAdapter(
                      child: SizedBox(height: InkScreenHeader.extent),
                    ),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(height: widget.topInset),
                        const CatalogueRefreshStatus(),
                        if (widget.header != null) widget.header!,
                      ],
                    ),
                  ),
                  if (tools != null) PinnedHeaderSliver(child: tools),
                  if (items.isNotEmpty)
                    if (_listView ||
                        volumesOnly ||
                        _kind == CatalogueKind.library ||
                        scale > 1.5)
                      SliverPadding(
                        padding: cataloguePadding,
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
                        columns: homeColumns,
                        topPadding: cataloguePadding.top,
                        itemCount: items.length,
                        artwork: items,
                        itemBuilder: (_, index) =>
                            InkCoverTile(item: items[index]),
                      )
                  else if (data.isLoading || state?.loading == true)
                    if (_listView ||
                        volumesOnly ||
                        _kind == CatalogueKind.library ||
                        scale > 1.5)
                      const SliverToBoxAdapter(child: InkSkeletonList())
                    else
                      CatalogueGrid(
                        key: const Key('catalogue-skeleton'),
                        columns: homeColumns,
                        topPadding: cataloguePadding.top,
                        itemCount: 12,
                        itemBuilder: coverSkeletonBuilder,
                      )
                  else
                    SliverToBoxAdapter(
                      child: InkEmptyState(
                        icon: data.hasError || state?.error == true
                            ? InkIcons.cloudSlash
                            : InkIcons.magnifyingGlassMinus,
                        title: data.hasError || state?.error == true
                            ? 'Catalogue unavailable'
                            : query.search.isNotEmpty || !query.filters.isEmpty
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
                  if (widget.embedded)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 152 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  if (widget.embedded && _filterMinimumExtent != null)
                    SliverLayoutBuilder(builder: _filterSpace),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return widget.embedded
        ? InkHomeHeader(pinned: true, actions: [search], child: scaffold)
        : scaffold;
  }

  Widget _libraryButton(
    CatalogueItem? library,
    AsyncValue<LocalCataloguePage> libraries, {
    bool floating = false,
  }) {
    final label =
        library?.title ??
        context.tr(_libraryId == null ? 'All libraries' : 'Selected library');
    if (floating) {
      return _HomeAction(
        key: const Key('catalogue-floating-library'),
        tooltip: context.tr('Choose a library'),
        onPressed: () async {
          final choice = await showInkPopup<(String?,)>(
            context: context,
            title: 'Choose a library',
            child: Builder(
              builder: (panelContext) => ListView(
                children: [
                  ListTile(
                    key: const Key('library-choice-all'),
                    selected: _libraryId == null,
                    leading: Icon(
                      _libraryId == null
                          ? InkIcons.checkCircle
                          : InkIcons.books,
                    ),
                    title: const LText('All libraries'),
                    onTap: () => Navigator.pop(panelContext, (null,)),
                  ),
                  ...libraries.when(
                    loading: () => [const LinearProgressIndicator()],
                    error: (_, _) => [
                      const LText('Saved libraries unavailable.'),
                    ],
                    data: (page) => [
                      for (final item in page.items)
                        ListTile(
                          key: ValueKey('library-choice-${item.id}'),
                          selected: item.id == _libraryId,
                          leading: Icon(
                            item.id == _libraryId
                                ? InkIcons.checkCircle
                                : InkIcons.books,
                          ),
                          title: Text(item.title),
                          onTap: () => Navigator.pop(panelContext, (item.id,)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
          if (mounted && choice != null) _selectLibrary(choice);
        },
        icon: InkIcons.books,
      );
    }
    final compact =
        MediaQuery.sizeOf(context).width <= MediaQuery.sizeOf(context).height ||
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return PopupMenuButton<(String?,)>(
      key: const Key('library-selector'),
      tooltip: label,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      useRootNavigator: true,
      popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: InkoraMotion.tab),
      constraints: BoxConstraints(
        minWidth: 240,
        maxWidth: (MediaQuery.sizeOf(context).width - 32).clamp(240, 320),
        maxHeight: (MediaQuery.sizeOf(context).height * .6).clamp(48, 360),
      ),
      onSelected: _selectLibrary,
      itemBuilder: (_) => [
        CheckedPopupMenuItem<(String?,)>(
          key: const Key('library-choice-all'),
          value: (null,),
          checked: _libraryId == null,
          child: const LText('All libraries'),
        ),
        ...libraries.when(
          loading: () => [
            const PopupMenuItem<(String?,)>(
              enabled: false,
              child: LinearProgressIndicator(),
            ),
          ],
          error: (_, _) => [
            const PopupMenuItem<(String?,)>(
              enabled: false,
              child: LText('Saved libraries unavailable.'),
            ),
          ],
          data: (page) => [
            for (final item in page.items)
              CheckedPopupMenuItem<(String?,)>(
                key: ValueKey('library-choice-${item.id}'),
                value: (item.id,),
                checked: item.id == _libraryId,
                child: Text(item.title),
              ),
          ],
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 48,
          minWidth: 48,
          maxWidth: compact ? 48 : double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            label: compact ? label : null,
            hint: context.tr('Choose a library'),
            button: true,
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
        ),
      ),
    );
  }
}

/// Permanent Home controls: generous touch targets, flat accent surfaces and
/// no scroll listener or per-frame rebuild owner.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });
  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    icon: Icon(icon, size: 28),
  );
}
