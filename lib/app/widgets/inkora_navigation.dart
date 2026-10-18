import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';
import '../l10n/app_strings.dart';
import 'ink_surface.dart';

const _destinations = [
  ('Libraries', InkIcons.books),
  ('Downloads', InkIcons.downloadSimple),
  ('Settings', InkIcons.gearSix),
];

/// Three primary destinations in a centered, system-safe bottom bar.
/// Selection uses foreground color; only a tap paints an expanding ink circle.
class InkoraNavigation extends StatefulWidget {
  const InkoraNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.floating = true,
    this.opacity = 1,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool floating;
  final double opacity;

  @override
  State<InkoraNavigation> createState() => _InkoraNavigationState();
}

class _InkoraNavigationState extends State<InkoraNavigation> {
  (String, TextStyle, TextScaler, TextDirection, double)? _measurementKey;
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
    _labelHeight = 0;
    _measurementCount++;
    for (final destination in _destinations) {
      final painter = TextPainter(
        text: TextSpan(text: context.tr(destination.$1), style: style),
        textDirection: direction,
        textScaler: scale,
      )..layout(maxWidth: maxWidth);
      _labelHeight = math.max(_labelHeight, painter.height);
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: widget.floating
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      child: Padding(
        padding: widget.floating
            ? const EdgeInsets.symmetric(horizontal: 12)
            : EdgeInsets.zero,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: widget.floating
                ? InkSurface(
                    key: const Key('floating-navigation-panel'),
                    opacity: widget.opacity,
                    child: _targets(context),
                  )
                : Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _targets(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _targets(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _measure(
        context,
        math.max(1.0, constraints.maxWidth / _destinations.length - 8),
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
  );

  TextStyle _labelStyle(BuildContext context, {required bool selected}) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: 11,
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
