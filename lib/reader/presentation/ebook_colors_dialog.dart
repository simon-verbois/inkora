import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../domain/ebook_settings.dart';
import 'reading_colors.dart';

/// Only this modal rebuilds while picking; the publication changes once on Save.
class EbookColorsDialog extends StatefulWidget {
  const EbookColorsDialog({super.key, required this.settings});
  final EbookSettings settings;

  @override
  State<EbookColorsDialog> createState() => _EbookColorsDialogState();
}

class _EbookColorsDialogState extends State<EbookColorsDialog> {
  late int _background = widget.settings.backgroundColor;
  late int _text =
      widget.settings.textColor ??
      (automaticEbookInk(Color(0xff000000 | _background)).toARGB32() &
          0xffffff);
  late bool _automatic = widget.settings.textColor == null;
  bool _backgroundValid = true, _textValid = true;

  @override
  Widget build(BuildContext context) {
    final fill = Color(0xff000000 | _background);
    final ink = _automatic
        ? automaticEbookInk(fill)
        : Color(0xff000000 | _text);
    return InkDialog(
      title: 'Custom colors',
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('ebook-color-preview'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                'Aa Bb Cc · 0123',
                style: TextStyle(color: ink, fontSize: 24),
              ),
            ),
            const SizedBox(height: 20),
            _ColorEditor(
              id: 'background',
              label: 'Background',
              initial: _background,
              onChanged: (value, valid) => setState(() {
                _background = value;
                _backgroundValid = valid;
              }),
            ),
            SwitchListTile.adaptive(
              key: const Key('ebook-automatic-text'),
              contentPadding: EdgeInsets.zero,
              title: const LText('Automatic text color'),
              value: _automatic,
              onChanged: (value) => setState(() {
                _automatic = value;
                _textValid = true;
              }),
            ),
            if (!_automatic)
              _ColorEditor(
                id: 'text',
                label: 'Text color',
                initial: _text,
                onChanged: (value, valid) => setState(() {
                  _text = value;
                  _textValid = valid;
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Cancel'),
        ),
        FilledButton(
          key: const Key('ebook-colors-save'),
          onPressed: _backgroundValid && (_automatic || _textValid)
              ? () => Navigator.pop(context, (
                  background: _background,
                  text: _automatic ? null : _text,
                ))
              : null,
          child: const LText('Save'),
        ),
      ],
    );
  }
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({
    required this.id,
    required this.label,
    required this.initial,
    required this.onChanged,
  });
  final String id, label;
  final int initial;
  final void Function(int value, bool valid) onChanged;

  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late HSVColor _color = HSVColor.fromColor(Color(0xff000000 | widget.initial));
  late final _hex = TextEditingController(text: _format(widget.initial));
  bool _valid = true;

  String _format(int rgb) =>
      rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

  void _slide(HSVColor color) {
    final rgb = color.toColor().toARGB32() & 0xffffff;
    setState(() {
      _color = color;
      _valid = true;
      _hex.text = _format(rgb);
    });
    widget.onChanged(rgb, true);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  List<Color> _ramp(String channel) => switch (channel) {
    'hue' => const [
      Colors.red,
      Colors.yellow,
      Colors.green,
      Colors.cyan,
      Colors.blue,
      Colors.purple,
      Colors.red,
    ],
    'saturation' => [
      _color.withSaturation(0).toColor(),
      _color.withSaturation(1).toColor(),
    ],
    _ => [Colors.black, _color.withValue(1).toColor()],
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: LText(
          widget.label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: Key('ebook-${widget.id}-hex'),
        controller: _hex,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
        ],
        decoration: InputDecoration(
          labelText: context.tr('Hex color'),
          prefixText: '#',
          helperText: 'RRGGBB',
          errorText: _valid
              ? null
              : context.tr('Enter six hexadecimal digits.'),
        ),
        onChanged: (text) {
          final valid = text.length == 6;
          final rgb = valid
              ? int.parse(text, radix: 16)
              : _color.toColor().toARGB32() & 0xffffff;
          setState(() {
            _valid = valid;
            if (valid) _color = HSVColor.fromColor(Color(0xff000000 | rgb));
          });
          widget.onChanged(rgb, valid);
        },
      ),
      for (final (id, label, value, maximum, change)
          in <(String, String, double, double, HSVColor Function(double))>[
            ('hue', 'Hue', _color.hue, 360, (value) => _color.withHue(value)),
            (
              'saturation',
              'Saturation',
              _color.saturation,
              1,
              (value) => _color.withSaturation(value),
            ),
            (
              'brightness',
              'Brightness',
              _color.value,
              1,
              (value) => _color.withValue(value),
            ),
          ]) ...[
        LText(label),
        Semantics(
          label: context.tr(label),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(colors: _ramp(id)),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  key: Key('ebook-${widget.id}-$id'),
                  value: value,
                  max: maximum,
                  divisions: maximum == 360 ? 360 : 100,
                  semanticFormatterCallback: (value) =>
                      '${(value / maximum * (maximum == 360 ? 360 : 100)).round()}',
                  onChanged: (value) => _slide(change(value)),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
