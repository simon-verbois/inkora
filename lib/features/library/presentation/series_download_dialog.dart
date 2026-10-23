import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/volume_progress.dart';

typedef SeriesDownloadChoice = ({bool unreadOnly, bool removeFinished});

/// A draft only: dismissal never saves policy or enqueues downloads.
class SeriesDownloadDialog extends StatefulWidget {
  const SeriesDownloadDialog({
    super.key,
    required this.progress,
    required this.skip,
    required this.removeFinished,
  });
  final SeriesProgress progress;
  final Set<String> skip;
  final bool removeFinished;

  @override
  State<SeriesDownloadDialog> createState() => _SeriesDownloadDialogState();
}

List<String> seriesDownloadTargets(
  SeriesProgress progress,
  Set<String> skip, {
  required bool unreadOnly,
}) => [
  for (final volume in progress.volumes)
    if (volume.available &&
        (volume.isEbook || volume.pageCount > 0) &&
        !skip.contains(volume.id) &&
        (!unreadOnly || !progress.of(volume.id).read))
      volume.id,
];

class _SeriesDownloadDialogState extends State<SeriesDownloadDialog> {
  bool _unreadOnly = false;
  late bool _removeFinished = widget.removeFinished;
  @override
  Widget build(BuildContext context) {
    final count = seriesDownloadTargets(
      widget.progress,
      widget.skip,
      unreadOnly: _unreadOnly,
    ).length;
    return InkDialog(
      title: 'Download volumes?',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<bool>(
            groupValue: _unreadOnly,
            onChanged: (value) => setState(() => _unreadOnly = value!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<bool>(
                  key: Key('download-series-all'),
                  value: false,
                  title: LText('Entire series'),
                ),
                const RadioListTile<bool>(
                  key: Key('download-series-unread'),
                  value: true,
                  title: LText('Unread and in-progress volumes'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            key: const Key('download-series-retention'),
            contentPadding: EdgeInsets.zero,
            title: const LText('Remove finished books from this device'),
            value: _removeFinished,
            onChanged: (value) => setState(() => _removeFinished = value),
          ),
          const LText(
            'For this series only, at least 24 hours after completion, on the next app launch or resume. Reading progress is kept.',
          ),
          const SizedBox(height: 16),
          LText(
            'Selection: {0}. The volumes are added to the download queue.',
            arguments: [AppStrings.of(context).quantity(count, 'book')],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('ink-confirm-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const LText('Cancel'),
        ),
        FilledButton(
          key: const Key('ink-confirm-accept'),
          onPressed: () => Navigator.pop(context, (
            unreadOnly: _unreadOnly,
            removeFinished: _removeFinished,
          )),
          child: const LText('Download'),
        ),
      ],
    );
  }
}
