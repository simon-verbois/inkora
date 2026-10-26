import 'package:flutter/material.dart';

import '../../../app/widgets/ink_filter_bar.dart';
import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../domain/catalogue_filters.dart';
import 'progress_format.dart';

IconData _readingIcon(ReadingStatus status) => switch (status) {
  ReadingStatus.any => InkIcons.books,
  ReadingStatus.unread => InkIcons.bookOpen,
  ReadingStatus.inProgress => InkIcons.circleHalf,
  ReadingStatus.completed => InkIcons.checkCircle,
};

/// Fitted Home alternative when the direct quick-filter row is too wide.
/// Uses the same filters/callback as the chips; it owns only its open menu.
class ReadingFilterMenu extends StatelessWidget {
  const ReadingFilterMenu({
    super.key,
    required this.filters,
    required this.onChanged,
  });
  final MetadataFilters filters;
  final ValueChanged<MetadataFilters> onChanged;

  void _select(ReadingStatus status, bool downloaded) => onChanged(
    MetadataFilters.from(
      filters.values,
      readingStatus: status,
      downloadedOnly: downloaded,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final label = context.tr(readingStatusLabel(filters.readingStatus));
    final description = filters.downloadedOnly
        ? '$label, ${context.tr('Downloaded')}'
        : label;
    return InkToolsMenu(
      buttonBuilder: (context, controller) => Tooltip(
        message: description,
        child: FilledButton.tonal(
          key: const Key('reading-filter-menu'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, InkoraLayout.controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_readingIcon(filters.readingStatus), size: 22),
              const SizedBox(width: InkSpace.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (filters.downloadedOnly) ...[
                const SizedBox(width: InkSpace.sm),
                Icon(
                  InkIcons.downloadSimple,
                  size: 18,
                  semanticLabel: context.tr('Downloaded'),
                ),
              ],
              const SizedBox(width: InkSpace.sm),
              const Icon(InkIcons.caretDown, size: 16),
            ],
          ),
        ),
      ),
      children: [
        for (final status in ReadingStatus.values)
          Semantics(
            selected: status == filters.readingStatus,
            child: MenuItemButton(
              key: ValueKey('reading-menu-${status.name}'),
              leadingIcon: Icon(_readingIcon(status)),
              trailingIcon: status == filters.readingStatus
                  ? const Icon(InkIcons.check)
                  : null,
              onPressed: () => _select(status, filters.downloadedOnly),
              child: LText(readingStatusLabel(status)),
            ),
          ),
        const Divider(),
        CheckboxMenuButton(
          key: const Key('reading-menu-downloaded'),
          value: filters.downloadedOnly,
          onChanged: (value) => _select(filters.readingStatus, value ?? false),
          child: const LText('Downloaded'),
        ),
      ],
    );
  }
}

/// Reading-status chips (All, Unread, In progress, Completed), then a
/// separator and the independent Downloaded toggle, for [InkFilterBar].
/// Offline views ([offline]) omit the redundant Downloaded toggle. Changes
/// keep the advanced metadata selections.
List<Widget> readingFilterChips({
  required MetadataFilters filters,
  required ValueChanged<MetadataFilters> onChanged,
  bool offline = false,
}) => [
  for (final status in ReadingStatus.values)
    InkFilterChip(
      key: ValueKey('reading-filter-${status.name}'),
      label: readingStatusLabel(status),
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
    const InkChipDivider(),
    InkFilterChip(
      key: const ValueKey('reading-filter-downloaded'),
      label: 'Downloaded',
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
