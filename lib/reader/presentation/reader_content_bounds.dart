import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../data/page_content_bounds_cache.dart';
import '../domain/page_content_bounds.dart';
import '../domain/page_source.dart';

/// Companion metadata cache to ReaderDecodedCache. Its lifecycle is wired to
/// account/revision invalidation, memory pressure and application visibility.
abstract final class ReaderContentBounds {
  static final cache = PageContentBoundsCache(_detect);

  static Future<PageContentBounds> _detect(EncodedPage page) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(page.bytes);
    ui.Codec? codec;
    ui.Image? image;
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        256 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).floor()),
        targetHeight: math.max(1, (descriptor.height * scale).floor()),
      );
      if (codec.frameCount != 1) return PageContentBounds.full;
      image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return PageContentBounds.full;
      final pixels = TransferableTypedData.fromList([
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      ]);
      return await compute(_scan, (pixels, image.width, image.height));
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

PageContentBounds _scan((TransferableTypedData, int, int) input) =>
    detectPageContentBounds(
      input.$1.materialize().asUint8List(),
      input.$2,
      input.$3,
    );
