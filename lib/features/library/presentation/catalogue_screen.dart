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
  String _searchQuery = '';
  int _initialWindowSize = 60;
  LocalCataloguePage? _sortingPage;
  String? _sortingAccount;
  bool _showUnavailable = false, _listView = false;
  MetadataFilters _metadataFilters = const MetadataFilters();

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
    _metadataFilters = widget.initialFilters;
    _initialWindowSize = 60;
    _sortingPage = null;
    _kind = widget.embedded ? CatalogueKind.series : widget.kind;
    _libraryId = widget.libraryId;
    _sort =
        widget.initialSort ??
        (widget.ordered || widget.seriesId != null
            ? CatalogueSort.sequence
            : CatalogueSort.title);
    _searchQuery = '';
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
    final result = await showInkSheet<CatalogueFilterResult>(
      context: context,
      child: CatalogueFiltersSheet(
        showUnavailable: _showUnavailable,
        filters: _metadataFilters,
        options: options,
        count: count,
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
    final librarySelection = widget.seriesId == null && widget.groupId == null;
    final search = InkHeaderSearch(
      key: const Key('catalogue-search'),
      controller: _search,
      hint: 'Search saved catalogue',
      compact: widget.embedded && MediaQuery.sizeOf(context).width < 600,
      onChanged: _searchChanged,
      onClear: _clearSearch,
    );
    final scaffold = Scaffold(
      appBar: widget.embedded
          ? null
          : InkScreenHeader(
              actions: [...widget.headerActions, search],
              title: LText(
                _kind == CatalogueKind.series ? 'Books' : catalogueLabel(_kind),
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: InkContent(
          child: RefreshIndicator(
            edgeOffset: widget.topInset,
            onRefresh: () => refreshCatalogue(ref),
            child: CustomScrollView(
              controller: _scroll,
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(height: widget.topInset),
                      const CatalogueRefreshStatus(),
                      if (widget.header != null) widget.header!,
                    ],
                  ),
                ),
                PinnedHeaderSliver(
                  child: ColoredBox(
                    key: const Key('catalogue-pinned-tools'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: InkFilterBar(
                      controlPrefix: 'catalogue',
                      leading: librarySelection
                          ? _libraryButton(selectedLibrary, libraries)
                          : Text(
                              AppStrings.of(context)
                                  .quantity(page?.total ?? 0, 'item'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                      chips:
                          _kind == CatalogueKind.book ||
                              _kind == CatalogueKind.series
                          ? readingFilterChips(
                              filters: _metadataFilters,
                              onChanged: (filters) =>
                                  _change(() => _metadataFilters = filters),
                            )
                          : const [],
                      sort: InkSortButton<CatalogueSort>(
                        key: const Key('catalogue-sort'),
                        value: _sort,
                        options: catalogueSortOptions(
                          sequence:
                              widget.groupId != null || widget.seriesId != null,
                          groupOrder: widget.groupId != null,
                        ),
                        onSelected: _sortChanged,
                      ),
                      filterCount: _metadataFilters.values.length,
                      onFilters: _filters,
                      actions: [
                        if (_kind != CatalogueKind.book)
                          IconButton(
                            key: const Key('catalogue-view'),
                            tooltip: context.tr(
                              _listView ? 'Show grid' : 'Show list',
                            ),
                            onPressed: () =>
                                setState(() => _listView = !_listView),
                            icon: Icon(
                              _listView ? InkIcons.squaresFour : InkIcons.list,
                              size: 20,
                            ),
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
                      columns: homeColumns,
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
    return widget.embedded
        ? InkHomeHeader(
            pinned: true,
            actions: [...widget.headerActions, search],
            child: scaffold,
          )
        : scaffold;
  }

  Widget _libraryButton(
    CatalogueItem? library,
    AsyncValue<LocalCataloguePage> libraries,
  ) {
    final label =
        library?.title ??
        context.tr(_libraryId == null ? 'All libraries' : 'Selected library');
    final compact =
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
