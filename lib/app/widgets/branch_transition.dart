import 'package:flutter/material.dart';

import '../theme/inkora_motion.dart';

/// Keep each branch Navigator in one stable slot. Only the incoming branch is
/// painted; no AnimatedSwitcher duplicates/reparents global Navigator keys.
class BranchTransition extends StatefulWidget {
  const BranchTransition({
    required this.index,
    required this.children,
    super.key,
  });
  final int index;
  final List<Widget> children;

  @override
  State<BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<BranchTransition>
    with SingleTickerProviderStateMixin {
  late final _entry = AnimationController(
    vsync: this,
    duration: InkoraMotion.tab,
    value: 1,
  );
  late final _opacity = _entry.drive(CurveTween(curve: Curves.easeOutCubic));
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) _entry.value = 1;
  }

  @override
  void didUpdateWidget(BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_reduced) _entry.forward(from: 0);
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: widget.index,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index
                  ? _opacity
                  : const AlwaysStoppedAnimation(1),
              child: widget.children[i],
            ),
          ),
        ),
    ],
  );
}
