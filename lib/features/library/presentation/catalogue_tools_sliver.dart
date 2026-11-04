import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports only crossings of the fixed header's lower edge. The toolbar stays
/// in the normal sliver flow; no widget/delegate is recreated on scroll frames.
class CatalogueToolsSliver extends SingleChildRenderObjectWidget {
  const CatalogueToolsSliver({
    super.key,
    required this.headerExtent,
    required this.onObscuredChanged,
    required super.child,
  });
  final double headerExtent;
  final ValueChanged<bool> onObscuredChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ToolsSliver(headerExtent, onObscuredChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSliverToBoxAdapter renderObject,
  ) {
    (renderObject as _ToolsSliver)
      ..headerExtent = headerExtent
      ..onObscuredChanged = onObscuredChanged;
  }
}

class _ToolsSliver extends RenderSliverToBoxAdapter {
  _ToolsSliver(this._headerExtent, this.onObscuredChanged);
  double _headerExtent;
  ValueChanged<bool> onObscuredChanged;
  bool _obscured = false, _scheduled = false;
  bool? _reported;

  set headerExtent(double value) {
    if (_headerExtent == value) return;
    _headerExtent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    final leading = constraints.scrollOffset > 0
        ? -constraints.scrollOffset
        : constraints.viewportMainAxisExtent - constraints.remainingPaintExtent;
    _obscured = leading + geometry!.scrollExtent <= _headerExtent;
    if (_scheduled || _reported == _obscured) return;
    _scheduled = true;
    // Layout cannot mutate an overlay that is being laid out in the same frame.
    // Coalesce a resize/scroll burst and publish only its final threshold state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || _reported == _obscured) return;
      _reported = _obscured;
      onObscuredChanged(_obscured);
    });
  }
}
