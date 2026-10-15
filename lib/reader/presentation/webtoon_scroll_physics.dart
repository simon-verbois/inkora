import 'package:flutter/widgets.dart';

import '../domain/reader_trace.dart';

/// WebtoonLayout already bounds the mounted/decode window by distance, strip
/// count and RGBA budget. Flutter's default velocity heuristic would defer a
/// newly mounted Image's codec until scrolling slows, even with encoded bytes
/// ready, letting its empty strip enter the viewport during a fling.
///
/// Only change that admission hint. Platform drag, ballistic, overscroll and
/// boundary behavior continue through the inherited physics chain.
class WebtoonScrollPhysics extends ScrollPhysics {
  const WebtoonScrollPhysics({super.parent});

  @override
  WebtoonScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      WebtoonScrollPhysics(parent: buildParent(ancestor));

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) {
    ReaderTrace.sink?.call('decode-deferral', null, {
      'velocity': velocity,
      'offset': metrics.pixels,
      'deferred': false,
    });
    return false;
  }
}
