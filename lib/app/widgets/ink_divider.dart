import 'package:flutter/material.dart';

/// A rule that fades to transparent at both ends, like Home and EPUB spreads.
/// A plain gradient paint adds no opacity, blur or offscreen compositing layer.
class InkDivider extends StatelessWidget {
  const InkDivider({
    super.key,
    this.height,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });
  final double? height;
  final double thickness, indent, endIndent;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height ?? DividerTheme.of(context).space ?? 16,
    child: Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      child: Center(
        child: SizedBox(
          height: thickness,
          width: double.infinity,
          child: _Rule(color: color, vertical: false),
        ),
      ),
    ),
  );
}

class InkVerticalDivider extends StatelessWidget {
  const InkVerticalDivider({
    super.key,
    this.width,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });
  final double? width;
  final double thickness, indent, endIndent;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width ?? DividerTheme.of(context).space ?? 16,
    child: Padding(
      padding: EdgeInsets.only(top: indent, bottom: endIndent),
      child: Center(
        child: SizedBox(
          width: thickness,
          height: double.infinity,
          child: _Rule(color: color, vertical: true),
        ),
      ),
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color, required this.vertical});
  final Color? color;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    final ink =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: .22);
    return CustomPaint(painter: InkRulePainter(ink, vertical: vertical));
  }
}

/// Paints in local coordinates, caching the shader across scroll offsets.
class InkRulePainter extends CustomPainter {
  InkRulePainter(this.color, {required this.vertical});
  final Color color;
  final bool vertical;
  final _paint = Paint();
  Size? _shaderSize;
  @visibleForTesting
  int gradientBuilds = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (_shaderSize != size) {
      _shaderSize = size;
      gradientBuilds++;
      _paint.shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    }
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(InkRulePainter oldDelegate) =>
      color != oldDelegate.color || vertical != oldDelegate.vertical;
}

/// Keeps an existing row's bounds and background while fading its bottom rule.
class InkBottomDivider extends StatelessWidget {
  const InkBottomDivider({
    super.key,
    required this.child,
    this.backgroundColor,
  });
  final Widget child;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor ?? Colors.transparent,
    child: Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(child: InkDivider(height: 1)),
        ),
        child,
      ],
    ),
  );
}
