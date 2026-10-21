import 'package:flutter/widgets.dart';

/// Tracks whether a page is on screen: its navigator is active
/// ([TickerMode]) and no page route covers its own route or an enclosing
/// route (for example the root reader above a shell page).
///
/// Coverage follows each route's secondary animation, so it changes only when
/// a covering page finishes opening or starts closing — never per frame.
/// Sheets and dialogs are not page routes and keep the page visible.
mixin RouteVisibilityMixin<T extends StatefulWidget> on State<T> {
  final _routes = <Animation<double>>[];
  bool _routeVisible = true;
  bool _tickerActive = true;

  /// Whether the page is currently on screen.
  bool get routeVisible => _routeVisible;

  /// Called after [routeVisible] changes. Pages start visible, so a page
  /// mounted while already hidden receives one initial `false`.
  void routeVisibilityChanged(bool visible);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerActive = TickerMode.valuesOf(context).enabled;
    final animations = <Animation<double>>[];
    BuildContext? owner = context;
    while (owner != null) {
      final route = ModalRoute.of(owner);
      if (route == null) break;
      final secondary = route.secondaryAnimation;
      if (secondary != null) animations.add(secondary);
      owner = route.navigator?.context;
    }
    if (!_sameRoutes(animations)) {
      for (final animation in _routes) {
        animation.removeStatusListener(_statusChanged);
      }
      _routes
        ..clear()
        ..addAll(animations);
      for (final animation in _routes) {
        animation.addStatusListener(_statusChanged);
      }
    }
    _update();
  }

  bool _sameRoutes(List<Animation<double>> next) {
    if (next.length != _routes.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (!identical(next[i], _routes[i])) return false;
    }
    return true;
  }

  void _statusChanged(AnimationStatus _) {
    if (mounted) _update();
  }

  void _update() {
    final visible =
        _tickerActive && !_routes.any((animation) => animation.isCompleted);
    if (visible == _routeVisible) return;
    _routeVisible = visible;
    routeVisibilityChanged(visible);
  }

  @override
  void dispose() {
    for (final animation in _routes) {
      animation.removeStatusListener(_statusChanged);
    }
    _routes.clear();
    super.dispose();
  }
}
