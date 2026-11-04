import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/volume_progress.dart';

typedef SeriesDownloadChoice = ({
  bool unreadOnly,
  bool removeFinished,
  int keepAhead,
  bool downloadNow,
});

/// A draft only: dismissal never saves policy or enqueues downloads.
class SeriesDownloadDialog extends StatefulWidget {
  const SeriesDownloadDialog({
    super.key,
    required this.progress,
    required this.skip,
    required this.removeFinished,
    this.keepAhead = 0,
  });
  final SeriesProgress progress;
  final Set<String> skip;
  final bool removeFinished;
  final int keepAhead;

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
  late int _mode = widget.keepAhead;
  late bool _removeFinished = widget.removeFinished;
  @override
  Widget build(BuildContext context) {
    final count = seriesDownloadTargets(
      widget.progress,
      widget.skip,
      unreadOnly: _mode != 0,
    ).length;
    return InkDialog(
      title: 'Download volumes?',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<int>(
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<int>(
                  key: Key('download-series-all'),
                  value: 0,
                  title: LText('Entire series'),
                ),
                const RadioListTile<int>(
                  key: Key('download-series-unread'),
                  value: -1,
                  title: LText('Unread and in-progress volumes'),
                ),
                for (final count in [2, 3])
                  RadioListTile<int>(
                    key: ValueKey('download-series-ahead-$count'),
                    value: count,
                    title: LText(
                      'Keep the next {0} volumes offline',
                      arguments: [count],
                    ),
                  ),
                if (widget.keepAhead > 0)
                  const RadioListTile<int>(
                    key: Key('download-series-ahead-off'),
                    value: -2,
                    title: LText('Turn off automatic downloads'),
                  ),
              ],
            ),
          ),
          if (_mode > 0) ...[
            const LText(
              'Includes the volume in progress. The next volumes are queued as you read, while the app is open. Download network and storage limits apply.',
            ),
            const SizedBox(height: 16),
          ],
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
          if (_mode == 0 || _mode == -1)
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
            unreadOnly: _mode != 0,
            removeFinished: _removeFinished,
            keepAhead: _mode > 0 ? _mode : 0,
            downloadNow: _mode == 0 || _mode == -1,
          )),
          child: LText(_mode > 0 || _mode == -2 ? 'Save' : 'Download'),
        ),
      ],
    );
  }
}
