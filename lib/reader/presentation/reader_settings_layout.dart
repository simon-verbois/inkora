import 'package:flutter/material.dart';

/// Two aligned columns when labels have enough space; one at large text sizes.
/// Shared by document typography, page layout and image-format controls.
class ReaderSettingsGrid extends StatelessWidget {
  const ReaderSettingsGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 520 * scale ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Dense dropdown buttons have one text line. Keep long selected labels inside
/// that line; menus and the long-press/hover tooltip retain their full wording.
class ReaderSettingsSelectedValue extends StatelessWidget {
  const ReaderSettingsSelectedValue(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: text,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

/// Drag updates only this control. Scope/settings work commits once on release.
class ReaderSettingsSlider extends StatefulWidget {
  const ReaderSettingsSlider({
    super.key,
    this.sliderKey,
    required this.label,
    required this.formatValue,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onCommitted,
    this.enabled = true,
  });
  final Key? sliderKey;
  final String label;
  final String Function(double) formatValue;
  final double value, min, max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onCommitted;
  @override
  State<ReaderSettingsSlider> createState() => _ReaderSettingsSliderState();
}

class _ReaderSettingsSliderState extends State<ReaderSettingsSlider> {
  double? _drag;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(widget.label)),
          const SizedBox(width: 12),
          Text(
            widget.formatValue(_drag ?? widget.value),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      Slider(
        key: widget.sliderKey,
        value: _drag ?? widget.value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: widget.formatValue(_drag ?? widget.value),
        semanticFormatterCallback: widget.formatValue,
        onChanged: widget.enabled ? (v) => setState(() => _drag = v) : null,
        onChangeEnd: widget.enabled
            ? (v) {
                setState(() => _drag = null);
                widget.onCommitted(v);
              }
            : null,
      ),
    ],
  );
}
