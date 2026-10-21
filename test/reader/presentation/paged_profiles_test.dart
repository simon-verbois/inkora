import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/paged_layout.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

class ProfileRasterSource implements PageSource {
  ProfileRasterSource(this.bytes);
  final List<Uint8List> bytes;
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) async => EncodedPage(
    key: key,
    bytes: bytes[key.pageIndex],
    mediaType: 'image/png',
  );
}

void main() {
  testWidgets(
    'offset changes visible pages after a wide scan without moving the locator',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manifest = readerManifest(
        book: 'mixed-scan-offset',
        dimensions: [
          for (var i = 0; i < 5; i++) PageDimensions(1920, 3005),
          PageDimensions(3840, 3005),
          for (var i = 0; i < 12; i++) PageDimensions(1920, 3005),
        ],
      );
      final reader = OpenReader(
        manifest,
        FixturePageSource(),
        ReaderLocator(11),
      );
      final saved = <ReaderLocator>[];
      Future<void> show(bool offset) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderViewport(
                reader: reader,
                settings: ReadingSettings(
                  mode: ReadingMode.manga,
                  spreadOffset: offset,
                ),
                saveLocator: (locator) async => saved.add(locator),
                onToggleSpreadOffset: () {},
              ),
            ),
          ),
        );
        await settleReaderImages(tester);
      }

      List<int> visible() =>
          (tester
              .widgetList<ReaderPageImage>(find.byType(ReaderPageImage))
              .where((page) => page.visible)
              .map((page) => page.index)
              .toList()
            ..sort());
      await show(false);
      final viewport = tester.state(find.byType(ReaderViewport));
      expect(find.text('p. 11–12'), findsOneWidget);
      expect(visible(), [10, 11]);
      await show(true);
      expect(find.text('p. 12–13'), findsOneWidget);
      expect(visible(), [11, 12]);
      expect(tester.state(find.byType(ReaderViewport)), same(viewport));
      await show(false);
      expect(find.text('p. 11–12'), findsOneWidget);
      expect(visible(), [10, 11]);
      expect(saved, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  const captureKey = Key('profile-capture');
  final dimensions = [
    PageDimensions(100, 200),
    PageDimensions(150, 225),
    PageDimensions(300, 150),
    for (var i = 0; i < 3; i++) PageDimensions(100, 150),
  ];
  Future<ProfileRasterSource> source(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final bytes = <Uint8List>[];
        for (var i = 0; i < dimensions.length; i++) {
          final recorder = ui.PictureRecorder();
          final size = dimensions[i];
          Canvas(recorder).drawRect(
            Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
            Paint()..color = i == 0 ? Colors.red : Colors.blue,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(size.width, size.height);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          bytes.add(png!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
        return ProfileRasterSource(bytes);
      }))!;
  Future<void> mount(
    WidgetTester tester,
    OpenReader reader,
    ReadingSettings settings,
    List<ReaderLocator> saved,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: captureKey,
          child: ReaderViewport(
            reader: reader,
            settings: settings,
            saveLocator: (locator) async => saved.add(locator),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'fractional tablet spread leaves no background pixels at its seam',
    (tester) async {
      tester.view.physicalSize = const Size(1536, 1024);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = [PageDimensions(2001, 3003), PageDimensions(1997, 3011)];
      final rasters = (await tester.runAsync(() async {
        final result = <Uint8List>[];
        for (var index = 0; index < pages.length; index++) {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            Rect.fromLTWH(0, 0, 100, 150),
            Paint()
              ..color = index == 0
                  ? const Color(0xffff0000)
                  : const Color(0xff0000ff),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(100, 150);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          result.add(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
        return result;
      }))!;
      await mount(
        tester,
        OpenReader(
          readerManifest(book: 'fractional-seam', dimensions: pages),
          ProfileRasterSource(rasters),
          ReaderLocator(0),
        ),
        const ReadingSettings(mode: ReadingMode.manga, spreadOffset: false),
        [],
      );
      await settleReaderImages(tester);
      final seam = tester
          .getRect(find.byKey(const ValueKey('page-image-0')))
          .left;
      await tester.runAsync(() async {
        final capture = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
            .toImage(pixelRatio: 1.5);
        final data = (await capture.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = 150; y < capture.height - 150; y += 80) {
          for (
            var x = (seam * 1.5).floor() - 2;
            x <= (seam * 1.5).ceil() + 2;
            x++
          ) {
            expect(
              data.getUint8((y * capture.width + x) * 4 + 1),
              lessThan(8),
              reason: 'Background exposed at seam ($x, $y)',
            );
          }
        }
        capture.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'manga joins mixed-ratio pages RTL at maximum size and navigates wide/odd pages at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = <ReaderLocator>[];
        final reader = OpenReader(
          readerManifest(book: 'profile-color-book', dimensions: dimensions),
          await source(tester),
          ReaderLocator(0),
        );
        await mount(
          tester,
          reader,
          // Explicit two pages: the default pairs only landscape/tablet windows.
          const ReadingSettings(
            mode: ReadingMode.manga,
            layout: ReadingLayout.doublePage,
            spreadOffset: false,
          ),
          saved,
        );
        await settleReaderImages(tester);
        final right = tester.getRect(
          find.byKey(const ValueKey('page-image-0')),
        );
        final left = tester.getRect(find.byKey(const ValueKey('page-image-1')));
        expect(left.right, closeTo(right.left, .001));
        expect(left.height, closeTo(right.height, .001));
        expect(
          left.width + right.width,
          closeTo((size.height * (7 / 6)).clamp(0, size.width), .001),
        );
        expect(find.text('p. 1–2'), findsOneWidget);
        // Inspect real pixels on both sides of the seam, not just widget bounds.
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          final capture = await boundary.toImage(pixelRatio: 1);
          final data = await capture.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final origin = tester.getTopLeft(find.byKey(captureKey));
          final y = (right.center.dy - origin.dy).floor();
          int color(double x, int channel) => data!.getUint8(
            (y * capture.width + (x - origin.dx).floor()) * 4 + channel,
          );
          expect(color(left.right - 4, 2), greaterThan(200));
          expect(color(right.left + 4, 0), greaterThan(200));
          capture.dispose();
        });
        await tester.drag(
          find.byKey(const Key('paged-reader')),
          Offset(size.width, 0),
        );
        await settleReaderImages(tester);
        expect(
          tester
              .widget<PageView>(find.byKey(const Key('paged-reader')))
              .controller!
              .page,
          closeTo(1, .01),
          reason: 'RTL swipe must advance the whole spread',
        );
        expect(find.text('p. 3'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('page-image-2'))).width,
          closeTo(size.width, .001),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await settleReaderImages(tester);
        expect(find.text('p. 4–5'), findsOneWidget);
        await tester.tap(find.byTooltip('Next page'));
        await settleReaderImages(tester);
        expect(find.text('p. 6'), findsOneWidget);
        expect(
          saved.map((locator) => locator.pageIndex),
          containsAll([2, 4, 5]),
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Next page',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'comics uses single portrait and joined LTR landscape while preserving locator',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reader = OpenReader(
        readerManifest(count: 6),
        FixturePageSource(),
        ReaderLocator(2),
      );
      final saved = <ReaderLocator>[];
      await mount(
        tester,
        reader,
        const ReadingSettings(mode: ReadingMode.comics),
        saved,
      );
      await settleReaderImages(tester);
      expect(find.text('p. 3'), findsOneWidget);
      tester.view.physicalSize = const Size(1024, 768);
      await settleReaderImages(tester);
      expect(find.text('p. 3–4'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('page-image-2'))).right,
        closeTo(
          tester.getRect(find.byKey(const ValueKey('page-image-3'))).left,
          .001,
        ),
      );
      await tester.drag(
        find.byKey(const Key('paged-reader')),
        const Offset(-1024, 0),
      );
      await settleReaderImages(tester);
      expect(
        tester
            .widget<PageView>(find.byKey(const Key('paged-reader')))
            .controller!
            .page,
        closeTo(2, .01),
        reason: 'LTR swipe must advance the whole spread',
      );
      expect(find.text('p. 5–6'), findsOneWidget);
      expect(saved.last.pageIndex, 5);
      tester.view.physicalSize = const Size(390, 844);
      await settleReaderImages(tester);
      expect(find.text('p. 6'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'switching reading profiles keeps the current page and applies each presentation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reader = OpenReader(
        readerManifest(count: 8),
        FixturePageSource(),
        ReaderLocator(2),
      );
      for (final mode in [
        ReadingMode.comics,
        ReadingMode.manga,
        ReadingMode.webtoon,
        ReadingMode.manga,
      ]) {
        await mount(tester, reader, ReadingSettings(mode: mode), []);
        await settleReaderImages(tester);
        // Phone portrait: every profile shows a single page by default.
        expect(find.text('p. 3'), findsOneWidget);
        expect(find.byKey(const ValueKey('page-image-2')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('zoomed pan and two-finger pinch do not turn a manga spread', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(
      tester,
      OpenReader(
        readerManifest(count: 8),
        FixturePageSource(),
        ReaderLocator(0),
      ),
      const ReadingSettings(mode: ReadingMode.manga),
      [],
    );
    await settleReaderImages(tester);
    final view = find.byKey(const Key('paged-reader'));
    final transform = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
        .transformationController!;
    transform.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    await tester.drag(view, const Offset(300, 0));
    await settleReaderImages(tester);
    expect(tester.widget<PageView>(view).controller!.page, closeTo(0, .01));
    transform.value = Matrix4.identity();
    await tester.pump();
    final center = tester.getCenter(view);
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center - const Offset(40, 0));
    await second.down(center + const Offset(40, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(50, 0));
    await second.moveTo(center + const Offset(210, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await settleReaderImages(tester);
    expect(tester.widget<PageView>(view).controller!.page, closeTo(0, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'spread offset re-pairs pages and is one tap away in double-page mode',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reader = OpenReader(
        readerManifest(book: 'profile-offset-book', dimensions: dimensions),
        await source(tester),
        ReaderLocator(0),
      );
      var toggles = 0;
      Future<void> show(ReadingSettings settings) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderViewport(
                reader: reader,
                settings: settings,
                saveLocator: (_) async {},
                onToggleSpreadOffset: () => toggles++,
              ),
            ),
          ),
        );
        await settleReaderImages(tester);
      }

      await show(
        const ReadingSettings(mode: ReadingMode.manga, spreadOffset: false),
      );
      expect(find.text('p. 1–2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-spread-offset')));
      expect(toggles, 1);

      await show(
        const ReadingSettings(mode: ReadingMode.manga, spreadOffset: true),
      );
      expect(find.text('p. 1'), findsOneWidget, reason: 'first page alone');

      await show(
        const ReadingSettings(
          mode: ReadingMode.manga,
          layout: ReadingLayout.single,
        ),
      );
      expect(find.byKey(const Key('reader-spread-offset')), findsNothing);
    },
  );

  test(
    'offset groups keep wide pages alone and persist as a book override',
    () {
      final layout = PagedLayout(
        [for (var i = 0; i < 5; i++) PageDimensions(100, 150)],
        doublePages: true,
        offset: 1,
      );
      expect(layout.groups, [
        [0],
        [1, 2],
        [3, 4],
      ]);
      final plain = PagedLayout([
        for (var i = 0; i < 5; i++) PageDimensions(100, 150),
      ], doublePages: true);
      expect(plain.groups, [
        [0, 1],
        [2, 3],
        [4],
      ]);
      final saved = ReadingOverrides.fromJson(
        const ReadingOverrides(spreadOffset: true).toJson(),
      );
      expect(ReadingSettings.resolve([saved]).spreadOffset, isTrue);
    },
  );

  testWidgets(
    're-pairing mid-book keeps the page without a build-time setState',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Five portrait pages: [0,1][2,3][4] and [0][1,2][3,4] have the same
      // spread count, so the PageView state survives and jumps in build while
      // page index 1 moves to a pair that reports a different last page.
      final reader = OpenReader(
        readerManifest(
          book: 'profile-repair-book',
          dimensions: [for (var i = 0; i < 5; i++) PageDimensions(100, 150)],
        ),
        await source(tester),
        ReaderLocator(1),
      );
      final saved = <ReaderLocator>[];
      Future<void> show(bool offset) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderViewport(
                reader: reader,
                settings: ReadingSettings(
                  mode: ReadingMode.manga,
                  spreadOffset: offset,
                ),
                saveLocator: (locator) async => saved.add(locator),
                onToggleSpreadOffset: () {},
              ),
            ),
          ),
        );
        await settleReaderImages(tester);
      }

      await show(false);
      expect(find.text('p. 1–2'), findsOneWidget);
      // The group changes (0 -> 1): the PageView jumps during build and its
      // page callback would report a different page to the parent.
      await show(true);
      expect(tester.takeException(), isNull);
      expect(find.text('p. 2–3'), findsOneWidget);
      expect(
        tester
            .widget<PageView>(find.byKey(const Key('paged-reader')))
            .controller!
            .page,
        closeTo(1, .01),
      );
    },
  );
}
