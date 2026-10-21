import 'package:flutter/material.dart';

import '../theme/inkora_theme.dart';

/// A single painted surface: alpha affects its fill, never its text or icons.
/// No backdrop capture/blur or per-item compositing layer is introduced.
class InkSurface extends StatelessWidget {
  const InkSurface({
    super.key,
    required this.child,
    this.opacity = 1,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double opacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer.withValues(alpha: opacity.clamp(0, 1)),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: InkRadius.large,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Fixed subtle translucency for framed headers and modal sheets.
class InkOverlaySurface extends StatelessWidget {
  const InkOverlaySurface({super.key, required this.child});
  static const opacity = .96;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      InkSurface(opacity: opacity, child: child);
}
