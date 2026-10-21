import 'dart:math' as math;
import 'dart:typed_data';

import 'reader_manifest.dart';

/// Normalized source coordinates. Metadata only: never owns image pixels.
final class PageContentBounds {
  const PageContentBounds(this.left, this.top, this.right, this.bottom);
  static const full = PageContentBounds(0, 0, 1, 1);
  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;
  bool get cropped => this != full;
  PageDimensions dimensionsFor(PageDimensions source) => !cropped
      ? source
      : PageDimensions(
          math.max(1, (source.width * width).round()),
          math.max(1, (source.height * height).round()),
          sizeBytes: source.sizeBytes,
        );
  @override
  bool operator ==(Object other) =>
      other is PageContentBounds &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Conservative white-paper detection on a bounded thumbnail. Any dark pixel,
/// including a page number or isolated caption, contributes to the bounds.
PageContentBounds detectPageContentBounds(
  Uint8List rgba,
  int width,
  int height,
) {
  if (width < 1 ||
      height < 1 ||
      width * height > 256 * 256 ||
      rgba.length != width * height * 4) {
    throw ArgumentError('Expected bounded RGBA thumbnail');
  }
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final alpha = rgba[i + 3];
      // Composite transparency against paper; transparent padding is blank.
      if (255 - (255 - rgba[i]) * alpha ~/ 255 >= 248 &&
          255 - (255 - rgba[i + 1]) * alpha ~/ 255 >= 248 &&
          255 - (255 - rgba[i + 2]) * alpha ~/ 255 >= 248) {
        continue;
      }
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x);
      bottom = math.max(bottom, y);
    }
  }
  // Blank/title-only pages and uncertain detections retain their original fit.
  if (right < left ||
      (right - left + 1) < width * .5 ||
      (bottom - top + 1) < height * .5) {
    return PageContentBounds.full;
  }
  final padX = math.max(2 / width, .015), padY = math.max(2 / height, .015);
  var l = (left / width - padX).clamp(0.0, .2);
  var t = (top / height - padY).clamp(0.0, .2);
  var r = ((right + 1) / width + padX).clamp(.8, 1.0);
  var b = ((bottom + 1) / height + padY).clamp(.8, 1.0);
  if (1 - (r - l) < .025) {
    l = 0;
    r = 1;
  }
  if (1 - (b - t) < .025) {
    t = 0;
    b = 1;
  }
  return PageContentBounds(l, t, r, b);
}
