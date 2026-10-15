import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';
import '../l10n/app_strings.dart';

const _destinations = [
  ('Home', InkIcons.house),
  ('Libraries', InkIcons.books),
  ('Downloads', InkIcons.downloadSimple),
  ('Settings', InkIcons.gearSix),
];

/// A single icon-and-label touch target, shared by the sidebar and bottom bar.
/// Selection uses foreground color; only a tap paints an expanding ink circle.
class InkoraNavigation extends StatefulWidget {
  const InkoraNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.vertical = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool vertical;

  @override
  State<InkoraNavigation> createState() => _InkoraNavigationState();
}

class _InkoraNavigationState extends State<InkoraNavigation> {
  (String, TextStyle, TextScaler, TextDirection, double)? _measurementKey;
  double _labelWidth = 0;
  double _labelHeight = 0;
  int _measurementCount = 0;

  @visibleForTesting
  int get labelMeasurementCount => _measurementCount;

  void _measure(BuildContext context, double maxWidth) {
    final style = _labelStyle(context, selected: true);
    final scale = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final key = (
      AppStrings.of(context).language,
      style,
      scale,
      direction,
      maxWidth,
    );
    if (key == _measurementKey) return;
    _measurementKey = key;
    _labelWidth = 0;
    _labelHeight = 0;
    _measurementCount++;
    for (final destination in _destinations) {
      final painter = TextPainter(
        text: TextSpan(text: context.tr(destination.$1), style: style),
        textDirection: direction,
        textScaler: scale,
      )..layout(maxWidth: maxWidth);
      _labelWidth = math.max(_labelWidth, painter.width);
      _labelHeight = math.max(_labelHeight, painter.height);
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vertical) _measure(context, double.infinity);
    // Use the widest localized label, including its bold selected state.
    // The 24 pixels account for the rail and destination horizontal padding.
    final sidebarWidth = math.max(112.0, _labelWidth.ceilToDouble() + 24);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: widget.vertical
          ? SizedBox(
              width: sidebarWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _destination(context, i, minHeight: 64),
                      ),
                  ],
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Measure labels at the actual scale/width, including narrow
                  // phones with large text. All destinations keep equal height.
                  _measure(
                    context,
                    math.max(
                      1.0,
                      constraints.maxWidth / _destinations.length - 8,
                    ),
                  );
                  final height = math.max(56.0, 24 + _labelHeight + 12);
                  return Row(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: SizedBox(
                            height: height,
                            child: _destination(context, i, minHeight: 48),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  TextStyle _labelStyle(BuildContext context, {required bool selected}) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: widget.vertical ? 12 : 11,
        height: 1.2,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      );

  Widget _destination(
    BuildContext context,
    int index, {
    required double minHeight,
  }) {
    final destination = _destinations[index];
    final selected = index == widget.selectedIndex;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('navigation-${destination.$1.toLowerCase()}'),
        onTap: () => widget.onSelect(index),
        borderRadius: BorderRadius.circular(12),
        splashFactory: MediaQuery.disableAnimationsOf(context)
            ? NoSplash.splashFactory
            : InkRipple.splashFactory,
        splashColor: scheme.primary.withValues(alpha: .18),
        highlightColor: Colors.transparent,
        hoverColor: scheme.primary.withValues(alpha: .06),
        focusColor: scheme.primary.withValues(alpha: .12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.$2, color: foreground, size: 24),
                LText(
                  destination.$1,
                  textAlign: TextAlign.center,
                  style: _labelStyle(
                    context,
                    selected: selected,
                  ).copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
