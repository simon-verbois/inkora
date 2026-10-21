import '../../app/widgets/inkora_widgets.dart';

import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_settings.dart';
import 'reader_settings_layout.dart';

/// Local draft: presets and edge adjustments reach the reader only on Save.
class EbookMarginsDialog extends StatefulWidget {
  const EbookMarginsDialog({super.key, required this.settings});
  final EbookSettings settings;
  @override
  State<EbookMarginsDialog> createState() => _EbookMarginsDialogState();
}

class _EbookMarginsDialogState extends State<EbookMarginsDialog> {
  late bool _tablet;
  late Map<String, double> _edges;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    _edges =
        (widget.settings.pageInsets ??
                EbookPageInsets.preset(
                  tablet: _tablet,
                  scale: widget.settings.margins,
                ))
            .toJson();
  }

  @override
  Widget build(BuildContext context) => InkDialog(
    title: 'Page margins',
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tablet in [false, true])
                  ChoiceChip(
                    key: ValueKey('margin-device-$tablet'),
                    label: LText(tablet ? 'Tablet' : 'Phone'),
                    selected: _tablet == tablet,
                    onSelected: (_) => setState(() {
                      _tablet = tablet;
                      _edges = EbookPageInsets.preset(
                        tablet: tablet,
                        scale: 1,
                      ).toJson();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (scale, label) in const [
                  (.5, 'Narrow margins'),
                  (1.0, 'Balanced margins'),
                  (1.5, 'Wide margins'),
                  (2.0, 'Extra wide margins'),
                ])
                  ChoiceChip(
                    key: ValueKey('margin-preset-$scale'),
                    label: LText(label),
                    selected:
                        EbookPageInsets.fromJson(_edges) ==
                        EbookPageInsets.preset(tablet: _tablet, scale: scale),
                    onSelected: (_) => setState(
                      () => _edges = EbookPageInsets.preset(
                        tablet: _tablet,
                        scale: scale,
                      ).toJson(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const LText('Custom'),
            const SizedBox(height: 12),
            ReaderSettingsGrid(
              children: [
                for (final (edge, label) in const [
                  ('top', 'Top edge'),
                  ('bottom', 'Bottom edge'),
                  ('left', 'Left edge'),
                  ('right', 'Right edge'),
                ])
                  InkSlider(
                    sliderKey: ValueKey('ebook-margin-$edge'),
                    label: context.tr(label),
                    value: _edges[edge]!,
                    min: 0,
                    max: EbookPageInsets.maximum,
                    divisions: 160,
                    formatValue: (v) => context.tr('{0} px', [v.round()]),
                    onCommitted: (v) => setState(() => _edges[edge] = v),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const LText(
              'Camera cutouts and system edges always stay outside the text.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LText('Cancel'),
      ),
      FilledButton(
        key: const Key('ebook-margins-save'),
        onPressed: () =>
            Navigator.pop(context, EbookPageInsets.fromJson(_edges)),
        child: const LText('Save'),
      ),
    ],
  );
}
