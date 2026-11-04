import 'package:flutter/material.dart';

import '../../../app/widgets/ink_filter_bar.dart';
import '../../../app/icons/inkora_icons.dart';
import '../domain/catalogue_filters.dart';
import 'progress_format.dart';

IconData _readingIcon(ReadingStatus status) => switch (status) {
  ReadingStatus.any => InkIcons.books,
  ReadingStatus.unread => InkIcons.bookOpen,
  ReadingStatus.inProgress => InkIcons.circleHalf,
  ReadingStatus.completed => InkIcons.checkCircle,
};

/// Reading-status chips (All, Unread, In progress, Completed), then a
/// separator and the independent Downloaded toggle, for [InkFilterBar].
/// Offline views ([offline]) omit the redundant Downloaded toggle. Changes
/// keep the advanced metadata selections.
List<Widget> readingFilterChips({
  required MetadataFilters filters,
  required ValueChanged<MetadataFilters> onChanged,
  bool offline = false,
  bool separated = true,
  bool showLabels = false,
}) => [
  for (final status in ReadingStatus.values)
    InkFilterChip(
      key: ValueKey('reading-filter-${status.name}'),
      label: readingStatusLabel(status),
      showLabel: showLabels,
      icon: _readingIcon(status),
      selected: filters.readingStatus == status,
      onSelected: () => onChanged(
        MetadataFilters.from(
          filters.values,
          readingStatus: status,
          downloadedOnly: filters.downloadedOnly,
        ),
      ),
    ),
  if (!offline) ...[
    if (separated) const InkChipDivider(),
    InkFilterChip(
      key: const ValueKey('reading-filter-downloaded'),
      label: 'Downloaded',
      showLabel: showLabels,
      icon: InkIcons.downloadSimple,
      toggle: true,
      selected: filters.downloadedOnly,
      onSelected: () => onChanged(
        MetadataFilters.from(
          filters.values,
          readingStatus: filters.readingStatus,
          downloadedOnly: !filters.downloadedOnly,
        ),
      ),
    ),
  ],
];
