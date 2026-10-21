import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/page_content_bounds.dart';

Uint8List paper({int shade = 255}) {
  final pixels = Uint8List(100 * 160 * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = pixels[i + 1] = pixels[i + 2] = shade;
    pixels[i + 3] = 255;
  }
  return pixels;
}

void ink(Uint8List pixels, int left, int top, int right, int bottom) {
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final i = (y * 100 + x) * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = 0;
    }
  }
}

void main() {
  test('four paper margins are detected with conservative safety padding', () {
    final pixels = paper();
    ink(pixels, 12, 20, 88, 140);
    final bounds = detectPageContentBounds(pixels, 100, 160);
    expect(bounds.left, closeTo(.10, .001));
    expect(bounds.right, closeTo(.90, .001));
    expect(bounds.top, lessThan(20 / 160));
    expect(bounds.bottom, greaterThan(140 / 160));
    expect(bounds.cropped, true);
  });
  test('isolated page numbers and small edge marks are retained', () {
    final pixels = paper();
    ink(pixels, 12, 20, 88, 140);
    ink(pixels, 49, 153, 51, 155);
    ink(pixels, 3, 60, 4, 61);
    final bounds = detectPageContentBounds(pixels, 100, 160);
    expect(bounds.left, lessThan(3 / 100));
    expect(bounds.bottom, greaterThan(155 / 160));
  });
  test('blank, black, title-only and edge-to-edge pages keep their canvas', () {
    expect(detectPageContentBounds(paper(), 100, 160), PageContentBounds.full);
    expect(
      detectPageContentBounds(paper(shade: 0), 100, 160),
      PageContentBounds.full,
    );
    expect(
      detectPageContentBounds(Uint8List(100 * 160 * 4), 100, 160),
      PageContentBounds.full,
    );
    final title = paper();
    ink(title, 30, 60, 70, 80);
    expect(detectPageContentBounds(title, 100, 160), PageContentBounds.full);
    final bleed = paper();
    ink(bleed, 0, 0, 100, 160);
    expect(detectPageContentBounds(bleed, 100, 160), PageContentBounds.full);
    expect(
      detectPageContentBounds(paper(shade: 245), 100, 160),
      PageContentBounds.full,
    );
  });
  test('invalid or unbounded thumbnails are rejected', () {
    expect(
      () => detectPageContentBounds(Uint8List(4), 257, 257),
      throwsArgumentError,
    );
    expect(
      () => detectPageContentBounds(Uint8List(4), 0, 0),
      throwsArgumentError,
    );
  });
}
