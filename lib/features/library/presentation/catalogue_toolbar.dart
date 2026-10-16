import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';

/// Shared compact controls for online and offline catalogues.
class CatalogueToolbar extends StatelessWidget {
  const CatalogueToolbar({
    super.key,
    required this.leading,
    required this.searchOpen,
    required this.onSearch,
    required this.onFilters,
    required this.filtered,
    required this.sort,
    required this.controlPrefix,
    this.listView,
    this.onView,
  });
  final Widget leading, sort;
  final bool searchOpen, filtered;
  final bool? listView;
  final VoidCallback onSearch, onFilters;
  final VoidCallback? onView;
  final String controlPrefix;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: leading),
        ),
        IconButton(
          key: Key('$controlPrefix-search-toggle'),
          tooltip: context.tr('Search this view'),
          isSelected: searchOpen,
          icon: const Icon(InkIcons.magnifyingGlass, size: 20),
          onPressed: onSearch,
        ),
        IconButton(
          key: Key('$controlPrefix-filters'),
          tooltip: context.tr('Filters'),
          isSelected: filtered,
          icon: const Icon(InkIcons.slidersHorizontal, size: 20),
          onPressed: onFilters,
        ),
        if (listView != null)
          IconButton(
            tooltip: context.tr(listView! ? 'Show grid' : 'Show list'),
            onPressed: onView,
            icon: Icon(
              listView! ? InkIcons.squaresFour : InkIcons.list,
              size: 20,
            ),
          ),
        sort,
      ],
    ),
  );
}
