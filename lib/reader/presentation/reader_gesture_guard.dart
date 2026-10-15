import 'package:flutter/material.dart';

import '../domain/gesture_zones.dart';

/// Opaque hit-test bands keep PageView/zoom out of system-navigation edges.
/// They register no recognizers; Android retains its own back gesture.
class ReaderGestureGuard extends StatelessWidget {
  const ReaderGestureGuard({
    super.key,
    required this.zones,
    required this.child,
  });
  final GestureZones zones;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (zones.left > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: zones.left.clamp(0, bounds.maxWidth * .4),
            child: const Listener(
              key: Key('reader-dead-left'),
              behavior: HitTestBehavior.opaque,
            ),
          ),
        if (zones.right > 0)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: zones.right.clamp(0, bounds.maxWidth * .4),
            child: const Listener(
              key: Key('reader-dead-right'),
              behavior: HitTestBehavior.opaque,
            ),
          ),
        if (zones.top > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: zones.top.clamp(0, bounds.maxHeight * .4),
            child: const Listener(
              key: Key('reader-dead-top'),
              behavior: HitTestBehavior.opaque,
            ),
          ),
        if (zones.bottom > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: zones.bottom.clamp(0, bounds.maxHeight * .4),
            child: const Listener(
              key: Key('reader-dead-bottom'),
              behavior: HitTestBehavior.opaque,
            ),
          ),
      ],
    ),
  );
}
