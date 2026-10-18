import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/image_enhancement.dart';
import 'package:inkora/core/images/image_enhancement.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';
import 'package:inkora/reader/presentation/reader_image_effects.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  testWidgets(
    'enabled strength changes soft-edge pixels without changing source samples',
    (tester) async {
      final program = await tester.runAsync(
        () => ui.FragmentProgram.fromAsset(
          'assets/shaders/image_enhancement.frag',
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 8, 8),
        Paint()..color = const Color(0xFFCCCCCC),
      );
      for (final (x, gray) in [80, 110, 125, 155, 170, 180, 200, 204].indexed) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 1, 8),
          Paint()..color = Color.fromARGB(255, gray, gray, gray),
        );
      }
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(() => picture.toImage(8, 8)))!;
      picture.dispose();
      addTearDown(image.dispose);
      final captures = <List<int>>[];
      const key = Key('soft-edge');
      for (final (level, sampling) in [
        (ImageEnhancement.gentle, FilterQuality.low),
        (ImageEnhancement.strong, FilterQuality.low),
        (ImageEnhancement.strong, FilterQuality.none),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: ImageEnhancementScope(
                  level: level,
                  program: program,
                  child: EnhancedRawImage(
                    raw: RawImage(
                      image: image,
                      width: 128,
                      height: 128,
                      fit: BoxFit.fill,
                      filterQuality: sampling,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final snapshot = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(key))
            .toImage();
        final data = (await tester.runAsync(() => snapshot.toByteData()))!;
        captures.add([
          for (var x = 0; x < 128; x++) data.getUint8((64 * 128 + x) * 4),
        ]);
        snapshot.dispose();
        expect(
          tester
              .widget<EnhancedRawImage>(find.byType(EnhancedRawImage))
              .raw
              .image,
          same(image),
        );
      }
      expect(captures[0], isNot(equals(captures[1])));
      expect(
        captures[1],
        isNot(equals(captures[2])),
        reason: 'Changing only sampling must repaint the retained shader',
      );
      expect(
        captures.expand((row) => row),
        everyElement(inInclusiveRange(79, 205)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'strength changes borrow the same decoded page without reacquisition',
    (tester) async {
      final program = await tester.runAsync(
        () => ui.FragmentProgram.fromAsset(
          'assets/shaders/image_enhancement.frag',
        ),
      );
      final source = FixturePageSource();
      final manifest = readerManifest(count: 1);
      ui.Image? decoded;
      Object? provider;
      for (final level in [...ImageEnhancement.values, ImageEnhancement.off]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageEnhancementScope(
              level: level,
              program: program,
              child: SizedBox(
                width: 100,
                height: 150,
                child: ReaderPageImage(
                  manifest: manifest,
                  index: 0,
                  source: source,
                ),
              ),
            ),
          ),
        );
        await settleReaderImages(tester);
        final image = tester.widget<Image>(find.byType(Image));
        final enhanced = tester.widget<EnhancedRawImage>(
          find.byType(EnhancedRawImage),
        );
        decoded ??= enhanced.raw.image;
        provider ??= image.image;
        expect(enhanced.raw.image, same(decoded));
        expect(image.image, provider);
        expect(source.requests, hasLength(1));
        expect(find.byType(ImageFiltered), findsNothing);
        if (level == ImageEnhancement.off) {
          expect(find.byType(RawImage), findsOneWidget);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shader preserves image geometry, transparent alpha and flat colors',
    (tester) async {
      final program = await tester.runAsync(
        () => ui.FragmentProgram.fromAsset(
          'assets/shaders/image_enhancement.frag',
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = const Color(0xFF336699),
      );
      canvas.drawRect(
        const Rect.fromLTWH(16, 0, 16, 16),
        Paint()..color = const Color(0x80336699),
      );
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(() => picture.toImage(32, 32)))!;
      picture.dispose();
      addTearDown(image.dispose);
      const key = Key('enhancement-pixels');
      for (final fit in [BoxFit.fill, BoxFit.contain, BoxFit.cover]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: ImageEnhancementScope(
                  level: ImageEnhancement.strong,
                  program: program,
                  child: EnhancedRawImage(
                    colorFilter: fit == BoxFit.contain
                        ? visualColorFilter(VisualFilter.grayscale)
                        : null,
                    raw: RawImage(
                      image: image,
                      width: 128,
                      height: 128,
                      fit: fit,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.getSize(find.byKey(key)), const Size(128, 128));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final snapshot = await boundary.toImage();
        final data = (await tester.runAsync(
          () => snapshot.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
        ))!;
        for (final (x, y, alpha) in [
          (16, 16, 255),
          (100, 16, 128),
          (16, 100, 0),
        ]) {
          final offset = (y * snapshot.width + x) * 4;
          expect(data.getUint8(offset + 3), closeTo(alpha, 1));
          if (alpha != 0) {
            for (final (channel, expected)
                in (fit == BoxFit.contain ? [95, 95, 95] : [51, 102, 153])
                    .indexed) {
              expect(data.getUint8(offset + channel), closeTo(expected, 2));
            }
          }
        }
        snapshot.dispose();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
