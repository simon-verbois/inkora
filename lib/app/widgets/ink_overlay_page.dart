import 'package:flutter/material.dart';

import '../theme/inkora_motion.dart';
import 'ink_surface.dart';

/// A GoRouter-owned modal keeps the originating branch and its scroll state.
class InkOverlayPage<T> extends Page<T> {
  const InkOverlayPage({required this.child, super.key});
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    modalBarrierColor: Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    sheetAnimationStyle: InkoraMotion.sheetStyle(context),
    constraints: const BoxConstraints(maxWidth: 784),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: InkOverlaySurface(child: child),
      ),
    ),
  );
}
