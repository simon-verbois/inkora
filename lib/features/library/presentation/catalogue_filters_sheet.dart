import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_filter_bar.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/catalogue_filters.dart';
import 'catalogue_detail_widgets.dart' show humanizeMetadata;

typedef CatalogueFilterResult = ({
  bool showUnavailable,
  MetadataFilters filters,
});

/// Result count of a filter draft (catalogue: one indexed SQL COUNT;
/// Downloads: an in-memory match over the loaded shelf).
typedef CatalogueFilterCount = Future<int> Function(
  MetadataFilters filters,
  bool showUnavailable,
);

/// Display order of the advanced filter sections.
const _facetOrder = [
  CatalogueFacet.mediaType,
  CatalogueFacet.status,
  CatalogueFacet.genres,
  CatalogueFacet.tags,
  CatalogueFacet.authors,
  CatalogueFacet.publisher,
  CatalogueFacet.language,
  CatalogueFacet.ageRating,
];

String _sectionLabel(CatalogueFacet facet) => switch (facet) {
  CatalogueFacet.status => 'Publication status',
  _ => facet.label,
};

/// Short format names for server MIME types; other server values unchanged.
String facetValueLabel(
  BuildContext context,
  CatalogueFacet facet,
  String value,
) => switch (facet) {
  CatalogueFacet.mediaType => switch (value) {
    'application/epub+zip' => 'EPUB',
    'application/pdf' => 'PDF',
    'application/zip' ||
    'application/x-cbz' ||
    'application/vnd.comicbook+zip' => 'CBZ',
    'application/x-rar-compressed' ||
    'application/x-cbr' ||
    'application/vnd.comicbook-rar' => 'CBR',
    _ => value,
  },
  CatalogueFacet.status => context.tr(humanizeMetadata(value)),
  _ => value,
};

/// Advanced metadata filters as chips (one value per dimension). Reading
/// status and Downloaded live in the filter bar and pass through unchanged.
/// The footer shows the draft's result count, queried once per settled change
/// ([countDelay]); stale answers are ignored.
class CatalogueFiltersSheet extends StatefulWidget {
  const CatalogueFiltersSheet({
    super.key,
    required this.options,
    required this.filters,
    this.showUnavailable,
    this.count,
  });
  final Future<CatalogueFacets> options;
  final MetadataFilters filters;

  /// Null hides the unavailable-items switch (Downloads).
  final bool? showUnavailable;
  final CatalogueFilterCount? count;

  static const countDelay = Duration(milliseconds: 250);

  @override
  State<CatalogueFiltersSheet> createState() => _CatalogueFiltersSheetState();
}

class _CatalogueFiltersSheetState extends State<CatalogueFiltersSheet> {
  late bool _unavailable = widget.showUnavailable ?? false;
  late final _selected = Map<CatalogueFacet, String>.of(widget.filters.values);
  Timer? _countTimer;
  int _countRequest = 0;
  int? _count;

  MetadataFilters get _draft => MetadataFilters.from(
    _selected,
    readingStatus: widget.filters.readingStatus,
    downloadedOnly: widget.filters.downloadedOnly,
  );

  @override
  void initState() {
    super.initState();
    _scheduleCount(immediate: true);
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    super.dispose();
  }

  void _scheduleCount({bool immediate = false}) {
    final count = widget.count;
    if (count == null) return;
    _countTimer?.cancel();
    final request = ++_countRequest;
    void run() {
      count(_draft, _unavailable).then(
        (value) {
          if (mounted && request == _countRequest) {
            setState(() => _count = value);
          }
        },
        onError: (Object _) {
          if (mounted && request == _countRequest) {
            setState(() => _count = null);
          }
        },
      );
    }

    if (immediate) {
      run();
    } else {
      _countTimer = Timer(CatalogueFiltersSheet.countDelay, run);
    }
  }

  void _update(VoidCallback change) {
    setState(change);
    _scheduleCount();
  }

  void _select(CatalogueFacet facet, String? value) => _update(() {
    if (value == null) {
      _selected.remove(facet);
    } else {
      _selected[facet] = value;
    }
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSheetHeader(
          title: 'Filters',
          action: TextButton(
            key: const Key('filters-reset'),
            onPressed: _selected.isEmpty
                ? null
                : () => _update(_selected.clear),
            child: const LText('Reset'),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: InkSpace.lg),
            child: FutureBuilder<CatalogueFacets>(
              future: widget.options,
              builder: (context, snapshot) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.hasError)
                    const LText('Saved catalogue unavailable.')
                  else if (!snapshot.hasData)
                    const LinearProgressIndicator()
                  else
                    for (final facet in _facetOrder)
                      if (snapshot.data![facet]?.isNotEmpty == true ||
                          _selected.containsKey(facet))
                        _FacetSection(
                          key: ValueKey('filter-section-${facet.name}'),
                          facet: facet,
                          values: snapshot.data![facet] ?? const [],
                          selected: _selected[facet],
                          onSelected: (value) => _select(facet, value),
                        ),
                  if (widget.showUnavailable != null)
                    SwitchListTile(
                      key: const Key('filters-unavailable'),
                      contentPadding: EdgeInsets.zero,
                      title: const LText('Show unavailable items'),
                      subtitle: const LText(
                        'Keep removed titles and historical list entries visible.',
                      ),
                      value: _unavailable,
                      onChanged: (value) => _update(() => _unavailable = value),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpace.lg,
            InkSpace.sm,
            InkSpace.lg,
            InkSpace.lg,
          ),
          child: FilledButton(
            key: const Key('filters-apply'),
            onPressed: () => Navigator.pop(context, (
              showUnavailable: _unavailable,
              filters: _draft,
            )),
            child: Text(
              _count == null
                  ? strings.text('Show results')
                  : strings.text('Show results ({0})', [_count]),
              key: const Key('filters-result-count'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// One dimension's chips. Long lists show the first [collapsed] values, a
/// "+N" chip revealing [page] more at a time, and a local search over the
/// already loaded values (no query per keystroke). Only this section
/// rebuilds while searching.
class _FacetSection extends StatefulWidget {
  const _FacetSection({
    super.key,
    required this.facet,
    required this.values,
    required this.selected,
    required this.onSelected,
  });
  final CatalogueFacet facet;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  static const collapsed = 12, page = 60;

  @override
  State<_FacetSection> createState() => _FacetSectionState();
}

class _FacetSectionState extends State<_FacetSection> {
  TextEditingController? _search;
  String _query = '';
  int _limit = _FacetSection.collapsed;

  @override
  void dispose() {
    _search?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = {
      ...widget.values,
      if (widget.selected != null) widget.selected!,
    }.toList(growable: false);
    final searchable = values.length > _FacetSection.collapsed;
    final query = _query.toLowerCase();
    final matches = query.isEmpty
        ? values
        : [
            for (final value in values)
              if (facetValueLabel(
                context,
                widget.facet,
                value,
              ).toLowerCase().contains(query))
                value,
          ];
    final shown = matches.take(_limit).toList();
    final selected = widget.selected;
    if (selected != null && !shown.contains(selected)) {
      shown.insert(0, selected);
    }
    final remaining = matches.length - matches.take(_limit).length;
    return Padding(
      padding: const EdgeInsets.only(top: InkSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: LText(
              _sectionLabel(widget.facet),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (searchable) ...[
            const SizedBox(height: InkSpace.sm),
            TextField(
              key: ValueKey('filter-search-${widget.facet.name}'),
              controller: _search ??= TextEditingController(),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.tr('Search'),
                prefixIcon: const Icon(InkIcons.magnifyingGlass, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ],
          const SizedBox(height: InkSpace.sm),
          Wrap(
            spacing: InkSpace.xs + 2,
            runSpacing: InkSpace.xs,
            children: [
              for (final value in shown)
                InkFilterChip(
                  key: ValueKey('filter-${widget.facet.name}-$value'),
                  label: facetValueLabel(context, widget.facet, value),
                  translate: false,
                  selected: value == selected,
                  onSelected: () =>
                      widget.onSelected(value == selected ? null : value),
                ),
              if (remaining > 0)
                Tooltip(
                  message: context.tr('Show more'),
                  child: ActionChip(
                    key: ValueKey('filter-more-${widget.facet.name}'),
                    label: Text('+$remaining'),
                    onPressed: () =>
                        setState(() => _limit += _FacetSection.page),
                  ),
                )
              else if (_limit > _FacetSection.collapsed)
                ActionChip(
                  key: ValueKey('filter-less-${widget.facet.name}'),
                  label: const LText('Show less'),
                  onPressed: () =>
                      setState(() => _limit = _FacetSection.collapsed),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
