import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inkora_motion.dart';

/// Full-size horizontal navigation on Android, including system edge gestures.
/// InkoraPage owns eligibility; this observer only drives the accepted route.
class HorizontalPageTransitionsBuilder extends PageTransitionsBuilder {
  const HorizontalPageTransitionsBuilder();
  @override
  Duration get transitionDuration => InkoraMotion.forward;
  @override
  Duration get reverseTransitionDuration => InkoraMotion.reverse;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : _HorizontalPage(route: route, animation: animation, child: child);
}

class _HorizontalPage extends StatefulWidget {
  const _HorizontalPage({
    required this.route,
    required this.animation,
    required this.child,
  });
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;
  @override
  State<_HorizontalPage> createState() => _HorizontalPageState();
}

class _HorizontalPageState extends State<_HorizontalPage>
    with WidgetsBindingObserver {
  late Animation<Offset> _position;
  late Animation<Offset> _interactivePosition;
  bool _accepted = false;
  bool _interactive = false;
  void _bind() {
    final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
    _interactivePosition = tween.animate(widget.animation);
    _position = tween.animate(
      widget.animation.drive(CurveTween(curve: Curves.easeOutCubic)),
    );
    widget.animation.addStatusListener(_finished);
  }

  void _finished(AnimationStatus status) {
    if (_interactive &&
        (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed)) {
      setState(() => _interactive = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _bind();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_HorizontalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      oldWidget.animation.removeStatusListener(_finished);
      _bind();
    }
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    if (!widget.route.isCurrent || !widget.route.popGestureEnabled) {
      return false;
    }
    _accepted = true;
    setState(() => _interactive = true);
    widget.route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    if (_accepted) {
      widget.route.handleUpdateBackGestureProgress(
        progress: 1 - event.progress,
      );
    }
  }

  @override
  void handleCancelBackGesture() {
    if (!_accepted) return;
    _accepted = false;
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    if (!_accepted) return;
    _accepted = false;
    widget.route.handleCommitBackGesture();
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_finished);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _interactive ? _interactivePosition : _position,
    child: widget.child,
  );
}
