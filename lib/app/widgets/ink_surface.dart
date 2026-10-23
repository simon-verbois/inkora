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
    this.outlined = true,
  });

  final Widget child;
  final bool outlined;
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
        side: outlined
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Fixed subtle translucency for framed headers and modal sheets.
class InkOverlaySurface extends StatelessWidget {
  const InkOverlaySurface({
    super.key,
    required this.child,
    this.outlined = true,
  });
  static const opacity = .96;
  final Widget child;
  final bool outlined;

  @override
  Widget build(BuildContext context) =>
      InkSurface(opacity: opacity, outlined: outlined, child: child);
}
