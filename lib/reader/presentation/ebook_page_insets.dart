import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/ebook_settings.dart';

/// Keep camera cutouts/system edges outside the publication even in fullscreen.
/// Cap custom space on small/rotated windows to retain a usable text viewport.
EdgeInsets ebookPublicationInsets(
  EbookSettings settings,
  EdgeInsets safe,
  Size size, {
  double? devicePixelRatio,
}) {
  final custom = settings.pageInsets;
  final horizontal = math.max(0.0, size.width - safe.horizontal) * .3;
  final vertical = math.max(0.0, size.height - safe.vertical) * .3;
  final insets = EdgeInsets.fromLTRB(
    safe.left + math.min(custom?.left ?? 0, horizontal),
    safe.top + math.min(custom?.top ?? settings.margins * 24, vertical),
    safe.right + math.min(custom?.right ?? 0, horizontal),
    safe.bottom + math.min(custom?.bottom ?? settings.margins * 24, vertical),
  );
  if (devicePixelRatio == null) return insets;
  assert(devicePixelRatio > 0 && devicePixelRatio.isFinite);
  // Native platform surfaces must not be sampled at fractional device pixels.
  // Round outwards so cutout and gesture clearances are never reduced.
  double snap(double value) =>
      (value * devicePixelRatio).ceilToDouble() / devicePixelRatio;
  return EdgeInsets.fromLTRB(
    snap(insets.left),
    snap(insets.top),
    snap(insets.right),
    snap(insets.bottom),
  );
}
