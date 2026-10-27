import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_settings.dart';
import '../../app/icons/inkora_icons.dart';
import 'reader_settings_layout.dart';
import 'ebook_presentation.dart';
import 'ebook_margins_dialog.dart';
import 'ebook_font_picker.dart';

enum EbookControlsSection { all, layout, typography, navigation }

/// Shared by scoped library settings and the active ebook reader.
class EbookSettingsControls extends StatelessWidget {
  const EbookSettingsControls({
    super.key,
    required this.settings,
    required this.onChanged,
    this.pdf = false,
    this.backgroundPicker,
    this.section = EbookControlsSection.all,
  });
  final EbookSettings settings;
  final void Function(String key, Object value) onChanged;
  final bool pdf;
  final Widget? backgroundPicker;
  final EbookControlsSection section;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (section == EbookControlsSection.all ||
          section == EbookControlsSection.navigation)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _choice(
              context,
              'Reading mode',
              settings.scroll ? 'scroll' : 'pages',
              {'pages': 'Page by page', 'scroll': 'Continuous scrolling'},
              (value) => onChanged('scroll', value == 'scroll'),
            ),
            if (!pdf && EbookPresentation.supported && !settings.scroll)
              _toggle(
                context,
                'Tap to turn pages',
                settings.tapToTurnPages,
                (value) => onChanged('tapToTurnPages', value),
              ),
          ],
        ),
      if (section == EbookControlsSection.all ||
          section == EbookControlsSection.layout) ...[
        ReaderSettingsGrid(
          children: [
            if (!pdf)
              OutlinedButton.icon(
                key: const Key('ebook-margin-picker'),
                icon: const Icon(InkIcons.slidersHorizontal),
                label: const LText('Page margins'),
                onPressed: () async {
                  final result = await showDialog<EbookPageInsets>(
                    context: context,
                    builder: (_) => EbookMarginsDialog(settings: settings),
                  );
                  if (result != null && context.mounted) {
                    onChanged('pageInsets', result.toJson());
                  }
                },
              ),
            if (!pdf)
              _choice(context, 'Text columns', settings.columns, {
                'auto': 'Automatic',
                'one': 'One column',
                'two': 'Two columns',
              }, (v) => onChanged('columns', v)),
          ],
        ),
        if (!pdf &&
            EbookPresentation.supported &&
            !settings.scroll &&
            settings.columns != 'one') ...[
          const SizedBox(height: 16),
          _toggle(
            context,
            'Center page divider',
            settings.columnSeparator,
            (v) => onChanged('columnSeparator', v),
          ),
        ],
      ],

      if (!pdf &&
          (section == EbookControlsSection.all ||
              section == EbookControlsSection.typography)) ...[
        if (section == EbookControlsSection.all) const SizedBox(height: 20),
        if (backgroundPicker case final background?)
          Row(
            key: const Key('ebook-color-font-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: background),
              const SizedBox(width: 16),
              Expanded(
                child: EbookFontPicker(
                  font: settings.fontChoice,
                  onSelected: (font) => onChanged('font', font.id),
                ),
              ),
            ],
          )
        else
          EbookFontPicker(
            font: settings.fontChoice,
            onSelected: (font) => onChanged('font', font.id),
          ),
        const SizedBox(height: 16),
        _slider(
          context,
          'Line spacing',
          'lineHeight',
          settings.lineHeight,
          1,
          2.5,
          15,
        ),
        const SizedBox(height: 16),
        _toggle(
          context,
          'Justify text',
          settings.justify,
          (value) => onChanged('justify', value),
        ),
        _toggle(
          context,
          'Publisher styles',
          settings.publisherStyles,
          (value) => onChanged('publisherStyles', value),
        ),
      ],
    ],
  );

  Widget _toggle(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: LText(label),
    value: value,
    onChanged: onChanged,
  );
  Widget _choice(
    BuildContext context,
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => ReaderChoiceGroup(
    id: 'ebook-${label.toLowerCase().replaceAll(' ', '-')}',
    label: label,
    choices: options,
    selected: value,
    wrapLabels:
        label == 'Reading mode' &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3,
    onSelected: change,
  );
  Widget _slider(
    BuildContext context,
    String label,
    String key,
    double value,
    double min,
    double max,
    int divisions,
  ) => InkSlider(
    sliderKey: ValueKey('ebook-$key'),
    label: context.tr(label),
    formatValue: (v) =>
        context.tr('{0}×', [double.parse(v.toStringAsFixed(1))]),
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    onCommitted: (v) => onChanged(key, v),
  );
}
