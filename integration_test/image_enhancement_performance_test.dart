import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_readium/flutter_readium.dart' hide ReadiumReaderWidget;
import 'package:flutter_readium/reader_widget.dart' as native;
import 'package:inkora/app/widgets/image_enhancement.dart';
import 'package:inkora/core/images/image_enhancement.dart';
import 'package:inkora/reader/presentation/ebook_presentation.dart';

import 'support/ebook_fixtures.dart';
import 'support/image_ebook_fixture.dart';

// Isolated GPU comparison. This is not a network/cache/30-minute acceptance run.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('physical image enhancement comparison', (tester) async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/image_enhancement.frag',
    );
    final surface = ui.ImageFilter.isShaderFilterSupported
        ? await ui.FragmentProgram.fromAsset(
            'assets/shaders/surface_enhancement.frag',
          )
        : null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 768, 1024),
      Paint()..color = const Color(0xFFF3E8CD),
    );
    for (var i = 0; i < 80; i++) {
      canvas.drawRect(
        Rect.fromLTWH(24, 20.0 + i * 12, 600 - (i % 5) * 60, 5),
        Paint()
          ..color = Color.fromARGB(255, 35 + i * 2, 35 + i * 2, 35 + i * 2),
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(768, 1024);
    picture.dispose();
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/image-comparison',
    ).create();
    final pdf = await File('${directory.path}/fixture.pdf')
        .writeAsBytes(base64Decode(pdfFixtureBase64));
    final timings = <List<int>>[];
    void frames(List<ui.FrameTiming> values) {
      for (final value in values) {
        timings.add([
          value.buildDuration.inMicroseconds,
          value.rasterDuration.inMicroseconds,
        ]);
      }
    }

    final results = <Map<String, Object?>>[];
    final engine = FlutterReadium();
    final epub = await File('${directory.path}/fixture.epub')
        .writeAsBytes(base64Decode(imageEpubFixtureBase64));
    await engine.setLogLevel(LogLevel.error);
    await engine.setCustomHeaders({});
    final publication = await engine.openPublication(epub.uri.toString());
    var epubReady = false;
    final status = engine.onReaderStatusChanged.listen((value) {
      if (value == ReadiumReaderStatus.ready) epubReady = true;
    });
    binding.addTimingsCallback(frames);
    try {
      for (final layout in ['covers', 'spread', 'webtoon', 'pdf', 'epub']) {
        for (final level in [
          ImageEnhancement.off,
          ImageEnhancement.balanced,
          ImageEnhancement.strong,
          ImageEnhancement.off,
        ]) {
          final scroll = ScrollController();
          final animation = ValueNotifier(0.0);
          Widget raw({BoxFit fit = BoxFit.contain}) => EnhancedRawImage(
            raw: RawImage(
              image: image,
              fit: fit,
              filterQuality: FilterQuality.high,
            ),
          );
          Widget content = switch (layout) {
            'covers' => GridView.builder(
              controller: scroll,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: .7,
              ),
              itemCount: 100,
              itemBuilder: (_, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: raw(fit: BoxFit.cover),
              ),
            ),
            'webtoon' => ListView.builder(
              controller: scroll,
              itemCount: 30,
              itemBuilder: (_, _) =>
                  AspectRatio(aspectRatio: .75, child: raw(fit: BoxFit.fill)),
            ),
            'pdf' => EnhancedDocumentSurface(child: PdfViewer.file(pdf.path)),
            'epub' => native.ReadiumReaderWidget(
              publication: publication,
              preloadPreviousPositionCount: 1,
              preloadNextPositionCount: 2,
            ),
            _ => Row(
              children: [
                Expanded(child: raw()),
                Expanded(child: raw()),
              ],
            ),
          };
          epubReady = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ImageEnhancementScope(
                  level: level,
                  program: program,
                  surfaceProgram: surface,
                  child: AnimatedBuilder(
                    animation: animation,
                    child: content,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(animation.value, 0),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));
          if (layout == 'epub') {
            for (var attempt = 0; attempt < 100 && !epubReady; attempt++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(epubReady, isTrue);
            await EbookPresentation.configure(
              animations: true,
              separator: false,
              imageEnhancement: level,
            );
            await tester.pump(const Duration(milliseconds: 500));
          }
          debugPrint('IMAGE_PHASE_${layout}_${level.name}');
          final initialImages =
              PaintingBinding.instance.imageCache.liveImageCount;
          timings.clear();
          final rssBefore = ProcessInfo.currentRss;
          final samples = <int>[];
          for (var frame = 0; frame < 180; frame++) {
            animation.value = (frame % 60) / 60;
            if (layout == 'epub' && frame % 60 == 0) {
              await EbookPresentation.turn(
                frame == 60 ? 1 : -1,
                animated: true,
              );
            }
            if (scroll.hasClients) {
              scroll.jumpTo((frame < 90 ? frame : 180 - frame) * 8.0);
            }
            await tester.pump(const Duration(milliseconds: 16));
            if (frame % 30 == 0) samples.add(ProcessInfo.currentRss);
          }
          await tester.pump(const Duration(milliseconds: 300));
          results.add({
            'layout': layout,
            'level': level.name,
            'frames': List.of(timings),
            'rssBefore': rssBefore,
            'rssAfter': ProcessInfo.currentRss,
            'rssSamples': samples,
            'liveImagesBefore': initialImages,
            'liveImagesAfter':
                PaintingBinding.instance.imageCache.liveImageCount,
          });
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 300));
          scroll.dispose();
          animation.dispose();
        }
      }
      binding.reportData = {
        'mode': kProfileMode ? 'profile' : 'debug',
        'kind': 'image enhancement comparison',
        'shaderFilterSupported': surface != null,
        'sourceSize': [768, 1024],
        'refreshRate': tester.view.display.refreshRate,
        'pixelRatio': tester.view.devicePixelRatio,
        'physicalSize': [
          tester.view.physicalSize.width,
          tester.view.physicalSize.height,
        ],
        'network': 'none; synthetic decoded image and local PDF',
        'results': results,
        'limitations': [
          'Short GPU comparison; no 30-minute or whole-reader acceptance claim.',
          'Flutter frame timings exclude internal WebView raster work; use Android gfxinfo for native frames.',
        ],
      };
    } finally {
      binding.removeTimingsCallback(frames);
      await tester.pumpWidget(const SizedBox.shrink());
      await status.cancel();
      await engine.closePublication();
      image.dispose();
      await directory.delete(recursive: true);
    }
  });
}
