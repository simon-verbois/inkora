import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_settings.dart';
import '../../app/icons/inkora_icons.dart';
import 'reader_settings_layout.dart';
import 'ebook_presentation.dart';
import 'ebook_margins_dialog.dart';

enum EbookControlsSection { all, layout, typography }

/// Shared by scoped library settings and the active ebook reader.
class EbookSettingsControls extends StatelessWidget {
  const EbookSettingsControls({
    super.key,
    required this.settings,
    required this.onChanged,
    this.pdf = false,
    this.section = EbookControlsSection.all,
  });
  final EbookSettings settings;
  final void Function(String key, Object value) onChanged;
  final bool pdf;
  final EbookControlsSection section;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (section != EbookControlsSection.typography)
        ReaderSettingsGrid(
          children: [
            _toggle(
              context,
              'Continuous scrolling',
              settings.scroll,
              (v) => onChanged('scroll', v),
            ),
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
            if (!pdf &&
                EbookPresentation.supported &&
                !settings.scroll &&
                settings.columns != 'one')
              _toggle(
                context,
                'Center page divider',
                settings.columnSeparator,
                (v) => onChanged('columnSeparator', v),
              ),
          ],
        ),
      if (!pdf && section != EbookControlsSection.layout) ...[
        if (section == EbookControlsSection.all) const SizedBox(height: 20),
        ReaderSettingsGrid(
          children: [
            _choice(context, 'Font', settings.font, {
              'publisher': 'Publisher font',
              'serif': 'Serif',
              'sans-serif': 'Sans serif',
              'baskerville': 'Libre Baskerville',
            }, (v) => onChanged('font', v)),
            _toggle(
              context,
              'Publisher styles',
              settings.publisherStyles,
              (v) => onChanged('publisherStyles', v),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ReaderSettingsGrid(
          children: [
            _slider(
              context,
              'Text size',
              'fontSize',
              settings.fontSize,
              .7,
              2.5,
              18,
            ),
            _slider(
              context,
              'Line spacing',
              'lineHeight',
              settings.lineHeight,
              1,
              2.5,
              15,
            ),
            _toggle(
              context,
              'Justify text',
              settings.justify,
              (v) => onChanged('justify', v),
            ),
          ],
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
    formatValue: (v) => key == 'fontSize'
        ? context.tr('{0} %', [(v * 100).round()])
        : context.tr('{0}×', [double.parse(v.toStringAsFixed(1))]),
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    onCommitted: (v) => onChanged(key, v),
  );
}
