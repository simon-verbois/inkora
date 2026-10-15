import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_image_effects.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  testWidgets(
    'MIME quality updates reuse acquisition and decoded image identity',
    (tester) async {
      final source = FixturePageSource();
      final manifest = readerManifest(count: 1);
      Future<void> mount(RasterQuality quality) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 100,
                height: 150,
                child: ReaderPageImage(
                  manifest: manifest,
                  index: 0,
                  source: source,
                  imageQuality: {
                    RasterFormat.png: quality,
                    RasterFormat.jpeg: const RasterQuality(
                      sampling: ImageSampling.nearest,
                    ),
                  },
                ),
              ),
            ),
          ),
        );
        await settleReaderImages(tester);
      }

      await mount(const RasterQuality());
      final provider = tester.widget<Image>(find.byType(Image)).image;
      expect(
        tester.widget<Image>(find.byType(Image)).filterQuality,
        FilterQuality.high,
      );
      for (final filter in VisualFilter.values) {
        await mount(
          RasterQuality(sampling: ImageSampling.smooth, filter: filter),
        );
        expect(tester.widget<Image>(find.byType(Image)).image, provider);
        expect(
          tester.widget<Image>(find.byType(Image)).filterQuality,
          FilterQuality.low,
        );
        expect(
          find.byType(ReaderFilteredImage),
          filter == VisualFilter.original ? findsNothing : findsOneWidget,
        );
      }
      expect(source.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final (filter, expected) in [
    (VisualFilter.grayscale, [54, 54, 54]),
    (VisualFilter.sepia, [100, 89, 69]),
    (VisualFilter.inverted, [0, 255, 255]),
  ]) {
    testWidgets(
      'direct image paint applies ${filter.name} without an extra layer',
      (tester) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 10, 10),
          Paint()..color = const Color(0xFFFF0000),
        );
        final picture = recorder.endRecording();
        final pixels = await tester.runAsync(() => picture.toImage(10, 10));
        picture.dispose();
        addTearDown(pixels!.dispose);
        const key = Key('filtered-pixels');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ReaderFilteredImage(
                    filter: filter,
                    raw: RawImage(
                      image: pixels,
                      width: 100,
                      height: 100,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final captured = await boundary.toImage(pixelRatio: 1);
        final data = await tester.runAsync(
          () => captured.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset = (50 * captured.width + 50) * 4;
        for (var channel = 0; channel < 3; channel++) {
          expect(
            data!.getUint8(offset + channel),
            closeTo(expected[channel], 1),
          );
        }
        captured.dispose();
        // Paint.colorFilter is applied directly; no ColorFilterLayer/saveLayer.
        expect(find.byType(ColorFiltered), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
