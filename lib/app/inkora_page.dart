import 'package:flutter/material.dart';

/// Material transitions with predictive back limited to the visible navigator.
class InkoraPage<T> extends MaterialPage<T> {
  const InkoraPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.canPop,
    super.onPopInvoked,
  });

  @override
  Route<T> createRoute(BuildContext context) => _InkoraPageRoute<T>(this);
}

class _InkoraPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _InkoraPageRoute(InkoraPage<T> page)
    : super(settings: page, allowSnapshotting: page.allowSnapshotting);

  InkoraPage<T> get _page => settings as InkoraPage<T>;
  @override
  Widget buildContent(BuildContext context) => _page.child;
  @override
  bool get maintainState => _page.maintainState;
  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  bool get popGestureEnabled {
    // A nested route can remain isCurrent inside a covered shell or an
    // inactive tab. Flutter notifies every predictive-back observer, so those
    // routes must refuse the gesture before the visible root reader accepts it.
    // This reads existing navigation state only when a gesture is considered.
    var owner = navigator;
    while (owner != null) {
      if (!TickerMode.getValuesNotifier(owner.context).value.enabled) {
        return false;
      }
      final enclosing = ModalRoute.of(owner.context);
      if (enclosing == null) break;
      if (!enclosing.isCurrent) return false;
      owner = enclosing.navigator;
    }
    return super.popGestureEnabled;
  }
}
