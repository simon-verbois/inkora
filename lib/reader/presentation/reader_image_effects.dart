import 'package:flutter/material.dart';

import '../domain/image_quality.dart';

FilterQuality samplingQuality(ImageSampling sampling) => switch (sampling) {
  ImageSampling.nearest => FilterQuality.none,
  ImageSampling.smooth => FilterQuality.low,
  ImageSampling.high => FilterQuality.high,
};

/// Immutable matrices applied directly to the image paint. No offscreen layer,
/// processed byte copy, second decode or filtered-image cache is required.
ColorFilter? visualColorFilter(VisualFilter filter) => switch (filter) {
  VisualFilter.original => null,
  VisualFilter.grayscale => const ColorFilter.matrix([
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
  VisualFilter.sepia => const ColorFilter.matrix([
    .393,
    .769,
    .189,
    0,
    0,
    .349,
    .686,
    .168,
    0,
    0,
    .272,
    .534,
    .131,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]),
  VisualFilter.inverted => const ColorFilter.matrix([
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ]),
};

class ReaderFilteredImage extends StatelessWidget {
  const ReaderFilteredImage({
    required this.raw,
    required this.filter,
    super.key,
  });
  final RawImage raw;
  final VisualFilter filter;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: raw.width,
    height: raw.height,
    child: CustomPaint(painter: _ImagePainter(raw, filter)),
  );
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.raw, this.filter);
  final RawImage raw;
  final VisualFilter filter;
  @override
  void paint(Canvas canvas, Size size) {
    final image = raw.image;
    if (image == null) return;
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      scale: raw.scale,
      fit: raw.fit,
      filterQuality: raw.filterQuality,
      colorFilter: visualColorFilter(filter),
      invertColors: raw.invertColors,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) =>
      oldDelegate.raw.image != raw.image ||
      oldDelegate.filter != filter ||
      oldDelegate.raw.fit != raw.fit ||
      oldDelegate.raw.scale != raw.scale ||
      oldDelegate.raw.filterQuality != raw.filterQuality ||
      oldDelegate.raw.invertColors != raw.invertColors;
}
