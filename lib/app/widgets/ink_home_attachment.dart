import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/inkora_motion.dart';
import '../theme/inkora_theme.dart';
import 'ink_surface.dart';

/// Paint-only coordination between the Home header and its attached controls.
class _Attachments extends ChangeNotifier {
  final space = GlobalKey();
  final regions = <Object, (Rect, double)>{};
  void update(Object id, Rect rect, double opacity) {
    final next = (rect, opacity);
    if (regions[id] == next) return;
    regions[id] = next;
    notifyListeners();
  }

  void remove(Object id) {
    if (regions.remove(id) != null) notifyListeners();
  }
}

class _AttachmentScope extends InheritedWidget {
  const _AttachmentScope({required this.attachments, required super.child});
  final _Attachments attachments;
  static _Attachments? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AttachmentScope>()
      ?.attachments;
  @override
  bool updateShouldNotify(_AttachmentScope oldWidget) =>
      attachments != oldWidget.attachments;
}

/// One continuous outline; animation ticks repaint it without rebuilding Home.
class InkHomeAttachmentFrame extends StatefulWidget {
  const InkHomeAttachmentFrame({super.key, required this.child});
  final Widget child;
  @override
  State<InkHomeAttachmentFrame> createState() => _InkHomeAttachmentFrameState();
}

class _InkHomeAttachmentFrameState extends State<InkHomeAttachmentFrame> {
  final _attachments = _Attachments();
  @override
  void dispose() {
    _attachments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AttachmentScope(
    attachments: _attachments,
    child: Stack(
      key: _attachments.space,
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _Outline(
                  _attachments,
                  Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Outline extends CustomPainter {
  _Outline(this.attachments, this.color) : super(repaint: attachments);
  final _Attachments attachments;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      InkSpace.md,
      InkSpace.sm,
      size.width - InkSpace.md,
      InkSpace.sm + kToolbarHeight,
    );
    const radius = InkRadius.l;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final main = Path()
      ..moveTo(rect.left + radius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - radius,
      )
      ..lineTo(rect.left, rect.top + radius)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + radius, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + radius)
      ..lineTo(rect.right, rect.bottom - radius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - radius,
        rect.bottom,
      );
    canvas.drawPath(main, paint);
    final regions = attachments.regions.values.where((r) => r.$2 > 0).toList()
      ..sort((a, b) => a.$1.left.compareTo(b.$1.left));
    var cursor = rect.left + radius;
    final end = rect.right - radius;
    for (final (bounds, opacity) in regions) {
      final left = bounds.left;
      final right = bounds.right;
      if (left > cursor) {
        canvas.drawLine(
          Offset(cursor, rect.bottom),
          Offset(left, rect.bottom),
          paint..color = color,
        );
      }
      canvas.drawLine(
        Offset(left, rect.bottom),
        Offset(right, rect.bottom),
        paint..color = color.withValues(alpha: color.a * (1 - opacity)),
      );
      canvas.drawPath(
        InkHomeToolShape.openPath(bounds),
        paint..color = color.withValues(alpha: color.a * opacity),
      );
      cursor = right;
    }
    if (cursor < end) {
      canvas.drawLine(
        Offset(cursor, rect.bottom),
        Offset(end, rect.bottom),
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_Outline oldDelegate) =>
      color != oldDelegate.color || attachments != oldDelegate.attachments;
}

/// Only the surface alpha animates; labels and icons retain their opacity.
class InkHomeToolGroup extends StatefulWidget {
  const InkHomeToolGroup({
    super.key,
    required this.child,
    required this.attached,
    this.horizontalPadding = 20,
    this.compact = false,
  });
  final Widget child;
  final bool attached;
  final double horizontalPadding;

  /// A fitted, shallow side group on wide Home layouts.
  final bool compact;
  @override
  State<InkHomeToolGroup> createState() => _InkHomeToolGroupState();
}

class _InkHomeToolGroupState extends State<InkHomeToolGroup>
    with SingleTickerProviderStateMixin {
  final _box = GlobalKey();
  late final _fade = AnimationController(
    vsync: this,
    duration: InkoraMotion.tab,
  )..addListener(_tick);
  _Attachments? _attachments;
  Rect? _rect;
  bool _scheduled = false;
  void _tick() {
    if (widget.attached && _rect != null) {
      _attachments?.update(this, _rect!, Curves.easeOut.transform(_fade.value));
    }
  }

  void _measure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.attached) return;
      final box = _box.currentContext?.findRenderObject();
      final root = _attachments?.space.currentContext?.findRenderObject();
      if (box is RenderBox && root is RenderBox && box.hasSize) {
        _rect =
            root.globalToLocal(box.localToGlobal(Offset.zero)) &
            _surfaceSize(box.size, widget.compact);
        _tick();
      }
    });
  }

  void _target() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = widget.attached ? 1 : 0;
    } else if (widget.attached) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
    if (widget.attached) {
      _measure();
    } else {
      _attachments?.remove(this);
      _rect = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _AttachmentScope.of(context);
    if (next != _attachments) {
      _attachments?.remove(this);
      _attachments = next;
    }
    _target();
  }

  @override
  void didUpdateWidget(InkHomeToolGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target();
  }

  @override
  void dispose() {
    _attachments?.remove(this);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: _MeasureSize(
      onChange: _measure,
      child: CustomPaint(
        key: _box,
        painter: _GroupFill(
          _fade,
          Theme.of(context).colorScheme.surfaceContainer,
          widget.compact,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            widget.compact && widget.attached ? 0 : 4,
            widget.horizontalPadding,
            widget.compact && widget.attached ? 8 : 4,
          ),
          child: widget.compact
              ? Transform.translate(
                  offset: widget.attached ? const Offset(0, -6) : Offset.zero,
                  // Raise attached side controls into their shallow surface;
                  // detached controls align with the central chips. Both keep
                  // the same group height and full 48 dp input regions.
                  transformHitTests: false,
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    ),
  );
}

class _GroupFill extends CustomPainter {
  _GroupFill(this.fade, this.color, this.compact) : super(repaint: fade);
  final Animation<double> fade;
  final Color color;
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    if (fade.value == 0) return;
    canvas.drawPath(
      const InkHomeToolShape().getOuterPath(
        Offset.zero & _surfaceSize(size, compact),
      ),
      Paint()
        ..color = color.withValues(
          alpha:
              InkOverlaySurface.opacity * Curves.easeOut.transform(fade.value),
        ),
    );
  }

  @override
  bool shouldRepaint(_GroupFill oldDelegate) =>
      color != oldDelegate.color ||
      fade != oldDelegate.fade ||
      compact != oldDelegate.compact;
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});
  final VoidCallback onChange;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureBox(onChange);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureBox renderObject,
  ) => renderObject.onChange = onChange;
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onChange);
  VoidCallback onChange;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous != size) {
      _previous = size;
      onChange();
    }
  }
}

class InkHomeToolShape extends ShapeBorder {
  const InkHomeToolShape();
  static Path openPath(Rect rect) {
    final shoulder = (rect.width / 8).clamp(0.0, 12.0);
    final lower = (rect.height / 3).clamp(0.0, 18.0);
    return Path()
      ..moveTo(rect.left, rect.top)
      ..quadraticBezierTo(
        rect.left + shoulder,
        rect.top,
        rect.left + shoulder,
        rect.top + shoulder,
      )
      ..lineTo(rect.left + shoulder, rect.bottom - lower)
      ..quadraticBezierTo(
        rect.left + shoulder,
        rect.bottom,
        rect.left + shoulder + lower,
        rect.bottom,
      )
      ..lineTo(rect.right - shoulder - lower, rect.bottom)
      ..quadraticBezierTo(
        rect.right - shoulder,
        rect.bottom,
        rect.right - shoulder,
        rect.bottom - lower,
      )
      ..lineTo(rect.right - shoulder, rect.top + shoulder)
      ..quadraticBezierTo(
        rect.right - shoulder,
        rect.top,
        rect.right,
        rect.top,
      );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  ShapeBorder scale(double t) => this;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      openPath(rect)..close();
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

Size _surfaceSize(Size full, bool compact) => Size(
  full.width,
  compact ? (full.height - 20).clamp(0.0, full.height) : full.height,
);
