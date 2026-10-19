import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';
import '../domain/catalogue_filters.dart';

/// Wide inline choices and a compact popup share one immutable filter state.
class ReadingFilterChips extends StatelessWidget {
  const ReadingFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
    this.offline = false,
    this.compact = false,
  });
  final MetadataFilters filters;
  final ValueChanged<MetadataFilters> onChanged;
  final bool offline, compact;
  String _label(ReadingStatus status) => switch (status) {
    ReadingStatus.any => 'Any',
    ReadingStatus.unread => 'Unread',
    ReadingStatus.inProgress => 'In progress',
    ReadingStatus.completed => 'Completed',
  };

  void _select(ReadingStatus status) => onChanged(
    MetadataFilters.from(
      filters.values,
      readingStatus: status,
      downloadedOnly: filters.downloadedOnly,
    ),
  );

  void _toggleOffline() => onChanged(
    MetadataFilters.from(
      filters.values,
      readingStatus: filters.readingStatus,
      downloadedOnly: !filters.downloadedOnly,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final active =
          filters.readingStatus != ReadingStatus.any || filters.downloadedOnly;
      return PopupMenuButton<({ReadingStatus? status, bool offline})>(
        key: const Key('reading-quick-filter-menu'),
        tooltip: context.tr('Reading status'),
        icon: Badge(
          isLabelVisible: active,
          child: Icon(
            InkIcons.listChecks,
            size: 20,
            color: active ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        onSelected: (choice) =>
            choice.offline ? _toggleOffline() : _select(choice.status!),
        itemBuilder: (context) => [
          for (final status in ReadingStatus.values)
            CheckedPopupMenuItem(
              value: (status: status, offline: false),
              checked: filters.readingStatus == status,
              child: LText(_label(status)),
            ),
          if (!offline) ...[
            const PopupMenuDivider(),
            CheckedPopupMenuItem(
              value: (status: null, offline: true),
              checked: filters.downloadedOnly,
              child: const LText('Downloaded only'),
            ),
          ],
        ],
      );
    }
    return Wrap(
      key: const Key('reading-quick-filter-chips'),
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final status in ReadingStatus.values)
          ChoiceChip(
            showCheckmark: false,
            label: LText(_label(status)),
            selected: filters.readingStatus == status,
            onSelected: (_) => _select(status),
          ),
        if (!offline)
          FilterChip(
            label: const LText('Downloaded only'),
            selected: filters.downloadedOnly,
            onSelected: (_) => _toggleOffline(),
          ),
      ],
    );
  }
}
