import 'package:flutter/material.dart';

/// Drag updates only this control. Scope/settings work commits once on release.
class InkSlider extends StatefulWidget {
  const InkSlider({
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
  State<InkSlider> createState() => _InkSliderState();
}

class _InkSliderState extends State<InkSlider> {
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
