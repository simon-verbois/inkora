import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../domain/reader_trace.dart';

/// Records paint submission, not GPU completion or display scanout. Only
/// instantiated when an explicit diagnostic recorder is attached.
class ReaderPaintProbe extends SingleChildRenderObjectWidget {
  const ReaderPaintProbe({
    required this.page,
    required this.image,
    required super.child,
    super.key,
  });
  final int page;
  final ui.Image? image;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintProbe(page, image);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _PaintProbe).update(page, image);
  }
}

class _PaintProbe extends RenderProxyBox {
  _PaintProbe(this.page, this.image);
  int page;
  ui.Image? image;
  bool submitted = false;
  void update(int page, ui.Image? image) {
    if (this.page != page || this.image != image) submitted = false;
    this.page = page;
    this.image = image;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!submitted) {
      submitted = true;
      ReaderTrace.sink?.call('paint-submitted', page, {
        'x': localToGlobal(Offset.zero).dx,
        'y': localToGlobal(Offset.zero).dy,
        'width': size.width,
        'height': size.height,
      });
    }
    super.paint(context, offset);
  }
}
