import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../l10n/app_strings.dart';
import '../theme/inkora_theme.dart';

/// Marks a modal whose available height is already owned by its snap container.
class InkSheetViewport extends InheritedWidget {
  const InkSheetViewport({
    super.key,
    required super.child,
    this.scrollController,
  });
  final ScrollController? scrollController;
  static bool isResizableOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InkSheetViewport>() != null;
  static ScrollController? scrollControllerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<InkSheetViewport>()
      ?.scrollController;
  @override
  bool updateShouldNotify(InkSheetViewport oldWidget) =>
      scrollController != oldWidget.scrollController;
}

/// Full-width modal with handle resizing and expansion-first body scrolling.
/// Only this frame and its handle follow drag ticks;
/// the supplied content remains mounted through snapping and window resizing.
class InkSnapSheet extends StatefulWidget {
  const InkSnapSheet({
    super.key,
    required this.child,
    this.initialFraction = .6,
  });
  final Widget child;
  final double initialFraction;
  @override
  State<InkSnapSheet> createState() => _InkSnapSheetState();
}

class _InkSnapSheetState extends State<InkSnapSheet>
    with SingleTickerProviderStateMixin {
  double get _middle =>
      MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
          MediaQuery.sizeOf(context).height < 480
      ? 1
      : widget.initialFraction.clamp(.35, .9);
  late final _extent = AnimationController(
    vsync: this,
    value: widget.initialFraction.clamp(.35, .9),
  );
  double _settled = .6;
  bool _initialized = false;
  double _dragValue = .6;
  double _dragStart = .6;
  double _height = 1;
  bool _closing = false;
  bool _dragging = false;
  bool _bodyResizing = false;
  double _bodyDragValue = .6;
  late final _bodyScroll = _SheetScrollController(
    resize: _resizeFromBody,
    settle: _settleFromBody,
  );

  double _resizeFromBody(double delta) {
    if (!mounted ||
        _closing ||
        delta == 0 ||
        (delta < 0 && _extent.value >= 1)) {
      return delta;
    }
    if (!_bodyResizing) {
      _bodyDragValue = _extent.value;
      _bodyResizing = true;
      _extent.stop();
    }
    final consumed = delta < 0
        ? (-delta).clamp(0.0, (1 - _bodyDragValue) * _height)
        : delta;
    _bodyDragValue += delta < 0 ? consumed / _height : -consumed / _height;
    _extent.value = _bodyDragValue.clamp(_minimum, 1);
    return delta < 0 ? delta + consumed : 0;
  }

  bool _settleFromBody(double velocity) {
    if (!_bodyResizing || !mounted) return false;
    _bodyResizing = false;
    if (velocity < -700) {
      _snap(0);
      return true;
    }
    if (_extent.value >= .999 && velocity >= 0) {
      _settled = 1;
      return false;
    }
    final projected = (_bodyDragValue + velocity / _height * .18).clamp(
      0.0,
      1.0,
    );
    final target = [
      0.0,
      ..._stops,
    ].reduce((a, b) => (a - projected).abs() <= (b - projected).abs() ? a : b);
    _snap(target, velocity: velocity / _height);
    return true;
  }

  bool _customScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      _resizeFromBody(-notification.overscroll);
    } else if (notification is ScrollEndNotification && _bodyResizing) {
      _settleFromBody(-(notification.dragDetails?.primaryVelocity ?? 0));
    }
    return false;
  }

  double get _minimum =>
      (240 * MediaQuery.textScalerOf(context).scale(1) / _height).clamp(
        .25,
        _middle,
      );
  List<double> get _stops => {_minimum, _middle, 1.0}.toList()..sort();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _settled = _middle;
      _extent.value = _middle;
    }
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _snap(double target, {double velocity = 0}) {
    _extent.stop();
    if (target == 0) {
      _close();
      return;
    }
    _settled = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _extent.value = target;
    } else {
      _extent.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 420, damping: 40),
          _extent.value,
          target,
          velocity,
        ),
      );
    }
  }

  void _end(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = -(details.primaryVelocity ?? 0) / _height;
    final projected = (_dragValue + velocity * .18).clamp(0.0, 1.0);
    final stops = [0.0, ..._stops];
    final target = stops.reduce(
      (a, b) => (a - projected).abs() <= (b - projected).abs() ? a : b,
    );
    _snap(target, velocity: velocity);
  }

  void _expand() => _snap(
    _stops.firstWhere((stop) => stop > _extent.value + .02, orElse: () => 1),
  );

  void _collapse() => _snap(
    _stops.reversed.firstWhere(
      (stop) => stop < _extent.value - .02,
      orElse: () => _minimum,
    ),
  );

  void _toggle() {
    if (_extent.value < .99) {
      _snap(1);
    } else {
      final target = _middle < 1 ? _middle : _minimum;
      target >= .99 ? _close() : _snap(target);
    }
  }

  @override
  void dispose() {
    _bodyScroll.dispose();
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      _height = (bounds.maxHeight - MediaQuery.viewInsetsOf(context).bottom)
          .clamp(1, double.infinity);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AnimatedBuilder(
          animation: _extent,
          child: InkSheetViewport(
            scrollController: _bodyScroll,
            child: PrimaryScrollController(
              controller: _bodyScroll,
              child: NotificationListener<ScrollNotification>(
                onNotification: _customScroll,
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
          builder: (context, body) {
            final full = _extent.value >= .99;
            final radius = InkRadius.l * ((1 - _extent.value) / .1).clamp(0, 1);
            return SizedBox(
              width: bounds.maxWidth,
              height: _height * _extent.value,
              child: Material(
                key: const Key('ink-sheet-surface'),
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) {
                        _dragging = true;
                        _dragStart = _settled;
                        _dragValue = _extent.value;
                        _extent.stop();
                      },
                      onVerticalDragUpdate: (details) {
                        _dragValue -= details.delta.dy / _height;
                        _extent.value = _dragValue.clamp(_minimum, 1);
                      },
                      onVerticalDragEnd: _end,
                      onVerticalDragCancel: () {
                        // A tap also rejects the drag recognizer before start.
                        // Only restore a detent after a real cancelled drag.
                        if (!_dragging) return;
                        _dragging = false;
                        _snap(_dragStart);
                      },
                      child: Semantics(
                        label: context.tr(
                          full
                              ? (_minimum >= .99 ? 'Close' : 'Show less')
                              : 'Show more',
                        ),
                        onIncrease: full ? null : _expand,
                        onDecrease: _extent.value <= _minimum + .02
                            ? null
                            : _collapse,
                        child: InkWell(
                          key: const Key('ink-sheet-handle'),
                          onTap: _toggle,
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: body!),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Primary scroll ownership: upward drags expand before scrolling, while downward
/// drags return to the start before collapsing. Custom scrollers and horizontal
/// sliders retain their own owners.
class _SheetScrollController extends ScrollController {
  _SheetScrollController({required this.resize, required this.settle});
  final double Function(double) resize;
  final bool Function(double) settle;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    physics: AlwaysScrollableScrollPhysics(parent: physics),
    context: context,
    oldPosition: oldPosition,
    resize: resize,
    settle: settle,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.resize,
    required this.settle,
  });
  final double Function(double) resize;
  final bool Function(double) settle;

  @override
  void applyUserOffset(double delta) {
    if (delta > 0 && pixels > minScrollExtent) {
      final scroll = delta.clamp(0.0, pixels - minScrollExtent);
      super.applyUserOffset(scroll);
      delta -= scroll;
    }
    final remainder = resize(delta);
    if (remainder != 0) super.applyUserOffset(remainder);
  }

  @override
  void goBallistic(double velocity) =>
      super.goBallistic(settle(velocity) ? 0 : velocity);
}
