import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/presentation/ebook_paper_background.dart';
import 'package:inkora/reader/presentation/ebook_presentation.dart';

Future<Uint8List> tile() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 2),
    Paint()..color = const Color(0x05000000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'one cached tile fills every outer margin and survives color/DPR changes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final bytes = (await tester.runAsync(tile))!;
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(EbookPresentation.channel, (call) async {
            expect(call.method, 'paperTile');
            calls++;
            return bytes;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(EbookPresentation.channel, null),
      );
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      const key = Key('background-pixels');
      Future<void> mount({
        Color color = Colors.white,
        double dpr = 1,
        bool enabled = true,
      }) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(devicePixelRatio: dpr),
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: EbookPaperBackground(
                    color: color,
                    enabled: enabled,
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: ColoredBox(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await mount();
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
        if (PaintingBinding.instance.imageCache.pendingImageCount == 0) break;
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final pixels = (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!;
      }))!;
      int red(int x, int y) => pixels.getUint8((y * 100 + x) * 4);
      // All four margin bands contain the grain, even next to the outer edge.
      for (final (x, y) in [
        (0, 5),
        (98, 5),
        (0, 95),
        (98, 95),
        (48, 0),
        (48, 99),
      ]) {
        expect(red(x, y), lessThan(255));
        expect(red(x + 1, y), 255);
      }
      expect(red(50, 50), 255); // Publication child stays above the background.
      expect(calls, 1);
      await mount(color: Colors.black, dpr: 2);
      await tester.pumpAndSettle();
      await mount(enabled: false);
      await tester.pumpAndSettle();
      await mount();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(const EbookPaperImage(), const EbookPaperImage());
      expect(const EbookPaperImage(), isNot(const EbookPaperImage(version: 1)));
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test('tile bridge rejects absent or unbounded encoded data', () async {
    for (final bytes in [null, Uint8List(256 * 1024 + 1)]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            EbookPresentation.channel,
            (_) async => bytes,
          );
      await expectLater(EbookPresentation.paperTile(), throwsFormatException);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EbookPresentation.channel, null);
  });
}
