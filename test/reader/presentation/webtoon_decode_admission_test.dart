import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reader_trace.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';
import 'package:inkora/reader/presentation/reader_image_provider.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';

import '../../support/reader_fakes.dart';
import '../../support/tall_strip_fixture.dart';

class RealStripSource implements PageSource {
  RealStripSource(this.bytes);
  final Uint8List bytes;
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) async => EncodedPage(key: key, bytes: bytes, mediaType: 'image/png');
}

class DeferringPhysics extends ScrollPhysics {
  const DeferringPhysics({super.parent});
  @override
  DeferringPhysics applyTo(ScrollPhysics? ancestor) =>
      DeferringPhysics(parent: buildParent(ancestor));
  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) => true;
}

class DeferringBehavior extends MaterialScrollBehavior {
  const DeferringBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const DeferringPhysics();
}

void main() {
  for (final size in [const Size(1600, 2560), const Size(2560, 1600)]) {
    for (final height in [4286, 7000]) {
      testWidgets(
        'bounded Webtoon $height-pixel codecs start despite scroll deferral at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 2.125;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bytes = (await tester.runAsync(
            () => tallStripFixture(height: height),
          ))!;
          expect(bytes.length, greaterThan(500000));
          final source = RealStripSource(bytes);
          final manifest = readerManifest(
            book: 'decode-admission-${size.width}',
            dimensions: [
              for (var i = 0; i < 20; i++)
                PageDimensions(720, height, sizeBytes: bytes.length),
            ],
          );
          final codecs = <int>[];
          ReaderTrace.sink = (stage, page, data) {
            if (stage == 'codec-request') codecs.add(page!);
          };
          addTearDown(() => ReaderTrace.sink = null);
          await tester.pumpWidget(
            MaterialApp(
              scrollBehavior: const DeferringBehavior(),
              home: ReaderViewport(
                reader: OpenReader(
                  manifest,
                  source,
                  ReaderLocator(0, height == 4286 ? .5 : .8),
                ),
                settings: const ReadingSettings(mode: ReadingMode.webtoon),
                saveLocator: (_) async {},
              ),
            ),
          );
          await tester.pump();
          // Do not call precacheImage/settleReaderImages: those bypass the Image
          // widget's ScrollAwareImageProvider and concealed this defect before.
          expect(codecs, containsAll([0, 1]));
          final list = find.byKey(const Key('webtoon-reader'));
          final controller = tester.widget<ListView>(list).controller!;
          final imageFinder = find.byKey(
            const ValueKey('page-image-0'),
            skipOffstage: false,
          );
          final nextFinder = find.byKey(
            const ValueKey('page-image-1'),
            skipOffstage: false,
          );
          Finder rawOf(Finder image) => find.descendant(
            of: image,
            matching: find.byType(RawImage, skipOffstage: false),
            skipOffstage: false,
          );
          for (var attempt = 0; attempt < 60; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            final raw = find.descendant(
              of: imageFinder,
              matching: find.byType(RawImage, skipOffstage: false),
              skipOffstage: false,
            );
            if (raw.evaluate().isNotEmpty &&
                tester.widget<RawImage>(raw).image != null &&
                rawOf(nextFinder).evaluate().isNotEmpty &&
                tester.widget<RawImage>(rawOf(nextFinder)).image != null) {
              break;
            }
          }
          final raw = find.descendant(
            of: imageFinder,
            matching: find.byType(RawImage, skipOffstage: false),
            skipOffstage: false,
          );
          final frame = tester.widget<RawImage>(raw).image!;
          final provider =
              tester.widget<Image>(imageFinder).image as ReaderImageProvider;
          expect(frame.width, provider.width);
          expect(frame.height, provider.height);
          expect(frame.height, greaterThan(1000));
          expect(frame.width, greaterThan(100));
          final nextFrame = tester.widget<RawImage>(rawOf(nextFinder)).image!;
          expect(nextFrame.height, greaterThan(1000));
          final nextPage = find.byKey(
            ValueKey(manifest.key(1)),
            skipOffstage: false,
          );
          expect(tester.widget<ReaderPageImage>(nextPage).visible, isFalse);
          final original = controller.offset;
          for (var i = 0; i < 8; i++) {
            controller.jumpTo(original + (i.isEven ? 100 : 0));
            await tester.pump();
          }
          expect(codecs.where((page) => page == 0), hasLength(1));
          expect(tester.widget<RawImage>(raw).image, same(frame));
          controller.jumpTo(original + tester.getSize(list).height * 2);
          await tester.pump();
          expect(tester.widget<ReaderPageImage>(nextPage).visible, isTrue);
          expect(
            tester.widget<RawImage>(rawOf(nextFinder)).image,
            same(nextFrame),
          );
          expect(codecs.where((page) => page == 1), hasLength(1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
