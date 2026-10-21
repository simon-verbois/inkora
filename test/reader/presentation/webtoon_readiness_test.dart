import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/webtoon_layout.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';
import 'package:inkora/reader/presentation/reader_image_provider.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

class PreparedPageSource extends FixturePageSource
    implements PrioritizedPageSource {
  final visibleRequests = <ContentKey>[];
  final speculativeRequests = <ContentKey>[];
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) {
    visibleRequests.add(key);
    return super.read(key, cancellation: cancellation);
  }

  @override
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  }) {
    speculativeRequests.add(key);
    return super.read(key, cancellation: cancellation);
  }

  @override
  Future<void> invalidate(ContentKey key) async {}
}

class DecodingPageSource extends PreparedPageSource {
  final foreground = Completer<EncodedPage>();
  int aheadReads = 0, foregroundReads = 0;
  @override
  Future<EncodedPage> readAhead(
    ContentKey key, {
    required CancellationSignal cancellation,
    required PageRequest request,
  }) {
    aheadReads++;
    return SynchronousFuture(
      EncodedPage(key: key, bytes: fixtureRaster, mediaType: 'image/png'),
    );
  }

  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) {
    foregroundReads++;
    return foreground.future;
  }
}

void main() {
  for (final size in [const Size(1600, 2560), const Size(2560, 1600)]) {
    testWidgets('long strips decode before entry on a $size tablet', (
      tester,
    ) async {
      const ratio = 2.125;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixturePageSource();
      final manifest = readerManifest(
        book: 'tablet-tall-${size.width}',
        dimensions: [
          for (var i = 0; i < 12; i++)
            PageDimensions(720, i.isEven ? 7000 : 4300),
        ],
      );
      final viewport = size.height / ratio;
      final width = WebtoonLayout.readingWidth(size.width / ratio, viewport);
      final layout = WebtoonLayout(manifest.pages, width, 0);
      final offset = layout.offsets[2] - viewport * 1.25;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              reader: OpenReader(manifest, source, layout.locate(offset)),
              settings: const ReadingSettings(mode: ReadingMode.webtoon),
              saveLocator: (_) async {},
            ),
          ),
        ),
      );
      await settleReaderImages(tester);
      // The next long strip starts a quarter-screen below the viewport.
      // Its acquired/decoded image must already exist while still offscreen.
      final page = find.byKey(
        const ValueKey('page-image-2'),
        skipOffstage: false,
      );
      expect(page, findsOneWidget);
      final raw = find.descendant(
        of: page,
        matching: find.byType(RawImage, skipOffstage: false),
        skipOffstage: false,
      );
      final frame = tester.widget<RawImage>(raw).image;
      final provider = tester.widget<Image>(page).image as ReaderImageProvider;
      expect(frame, isNotNull);
      final reads = source.requests.where((key) => key.pageIndex == 2).length;
      expect(reads, 1);
      source.hold = true;
      final controller = tester
          .widget<ListView>(find.byKey(const Key('webtoon-reader')))
          .controller!;
      controller.jumpTo(controller.offset + viewport * .5);
      await tester.pump();
      expect(tester.widget<RawImage>(raw).image, same(frame));
      expect(
        (tester.widget<Image>(page).image as ReaderImageProvider).imageKey,
        provider.imageKey,
      );
      expect(source.requests.where((key) => key.pageIndex == 2).length, reads);
      expect(
        tester
            .widgetList<ReaderPageImage>(
              find.byType(ReaderPageImage, skipOffstage: false),
            )
            .fold<int>(0, (sum, image) => sum + image.decodeBudget),
        lessThanOrEqualTo(
          const ReadingSettings(mode: ReadingMode.webtoon)
                  .webtoonProfile
                  .memoryMiB *
              1024 *
              1024,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'prepared strip boundaries refit the live decode allowance during scroll',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixturePageSource()..hold = true;
      final manifest = readerManifest(
        book: 'scroll-memory-bound',
        dimensions: [
          for (var i = 0; i < 30; i++)
            i.isEven ? PageDimensions(2000, 1500) : PageDimensions(2000, 12000),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderViewport(
            reader: OpenReader(manifest, source, ReaderLocator(0)),
            settings: const ReadingSettings(mode: ReadingMode.webtoon),
            saveLocator: (_) async {},
          ),
        ),
      );
      final list = find.byKey(const Key('webtoon-reader'));
      final controller = tester.widget<ListView>(list).controller!;
      for (var offset = 0.0; offset <= 6000; offset += 150) {
        controller.jumpTo(offset);
        await tester.pump();
        final allowance = tester
            .widgetList<ReaderPageImage>(
              find.byType(ReaderPageImage, skipOffstage: false),
            )
            .fold(0, (sum, page) => sum + page.decodeBudget);
        expect(
          allowance,
          lessThanOrEqualTo(
            const ReadingSettings(mode: ReadingMode.webtoon)
                    .webtoonProfile
                    .memoryMiB *
                1024 *
                1024,
          ),
          reason: 'Mounted strip allowance at $offset',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'continuous webtoon uses a centered landscape column and preserves position on rotation',
    (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <ReaderLocator>[];
      final reader = OpenReader(
        readerManifest(book: 'comfortable-width', count: 30),
        FixturePageSource(),
        ReaderLocator(3, .3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderViewport(
            reader: reader,
            settings: const ReadingSettings(mode: ReadingMode.webtoon),
            saveLocator: (locator) async => saved.add(locator),
          ),
        ),
      );
      await settleReaderImages(tester);
      final list = find.byKey(const Key('webtoon-reader'));
      expect(tester.getRect(list).width, 768);
      final controller = tester.widget<ListView>(list).controller!;
      controller.jumpTo(controller.offset + 100);
      await tester.pump(const Duration(milliseconds: 200));
      final before = saved.last;
      tester.view.physicalSize = const Size(1280, 800);
      await settleReaderImages(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final rect = tester.getRect(list);
      expect(rect.width, 680);
      expect(rect.center.dx, 640);
      expect(saved.last.pageIndex, before.pageIndex);
      expect(saved.last.fraction, closeTo(before.fraction, .005));
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderViewport(
            reader: reader,
            settings: const ReadingSettings(
              mode: ReadingMode.webtoon,
              fit: ReadingFit.width,
            ),
            saveLocator: (locator) async => saved.add(locator),
          ),
        ),
      );
      await settleReaderImages(tester);
      expect(tester.getRect(list).width, 1280);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('foreground promotion preserves a decoding image subtree', (
    tester,
  ) async {
    final source = DecodingPageSource();
    final manifest = readerManifest(book: 'promotion-during-decode');
    Future<void> mountPage(bool visible) => tester.pumpWidget(
      MaterialApp(
        home: ReaderPageImage(
          manifest: manifest,
          index: 0,
          source: source,
          visible: visible,
        ),
      ),
    );
    await mountPage(false);
    final before = tester.element(find.byType(Image));
    await mountPage(true);
    expect(tester.element(find.byType(Image)), same(before));
    expect(source.aheadReads, 1);
    expect(source.foregroundReads, 1);
    source.foreground.complete(
      EncodedPage(
        key: manifest.key(0),
        bytes: fixtureRaster,
        mediaType: 'image/png',
      ),
    );
    await settleReaderImages(tester);
    expect(tester.element(find.byType(Image)), same(before));
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'webtoon page boundaries keep the parent surface and prepared pixels mounted',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixturePageSource();
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderViewport(
            reader: OpenReader(
              readerManifest(book: 'scroll-rebuild', count: 30),
              source,
              ReaderLocator(0),
            ),
            settings: const ReadingSettings(mode: ReadingMode.webtoon),
            saveLocator: (_) async {},
          ),
        ),
      );
      await settleReaderImages(tester);
      final surface = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ReaderViewport),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final list = tester.widget<ListView>(
        find.byKey(const Key('webtoon-reader')),
      );
      final currentPage = tester.widget<ReaderPageImage>(
        find.byType(ReaderPageImage).first,
      );
      final requests = source.requests.length;
      for (var offset = 1.0; offset < 40; offset += 3) {
        list.controller!.jumpTo(offset);
        await tester.pump();
      }
      expect(
        tester.widget<ListView>(find.byKey(const Key('webtoon-reader'))),
        same(list),
      );
      expect(
        tester.widget<ReaderPageImage>(find.byType(ReaderPageImage).first),
        same(currentPage),
      );
      expect(source.requests.length, requests);
      list.controller!.jumpTo(600);
      await tester.pump();
      expect(
        tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(ReaderViewport),
                matching: find.byType(ColoredBox),
              )
              .first,
        ),
        same(surface),
      );
      expect(find.text('p. 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  Future<void> mount(
    WidgetTester tester,
    OpenReader opened,
    ReadingSettings settings,
    List<ReaderLocator> saved,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReaderViewport(
          key: ValueKey(opened.manifest.key(0)),
          reader: opened,
          settings: settings,
          saveLocator: (locator) async => saved.add(locator),
        ),
      ),
    ),
  );

  testWidgets(
    'decode resize preserves its frame while a new account clears it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixturePageSource();
      final manifest = readerManifest(dimensions: [PageDimensions(2000, 4000)]);
      Future<void> page(
        ReaderManifest manifest,
        FixturePageSource source,
        int budget,
      ) => tester.pumpWidget(
        MaterialApp(
          home: ReaderPageImage(
            manifest: manifest,
            index: 0,
            source: source,
            decodeBudget: budget,
          ),
        ),
      );
      await page(manifest, source, 8 * 1024 * 1024);
      await settleReaderImages(tester);
      final frame = tester.widget<RawImage>(find.byType(RawImage)).image;
      final before =
          (tester.widget<Image>(find.byType(Image)).image
                  as ReaderImageProvider)
              .imageKey;
      await page(manifest, source, 4 * 1024 * 1024);
      final after =
          (tester.widget<Image>(find.byType(Image)).image
                  as ReaderImageProvider)
              .imageKey;
      expect(after, isNot(before));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(frame));
      expect(frame, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await page(
        readerManifest(account: 'another-account', dimensions: manifest.pages),
        FixturePageSource()..hold = true,
        4 * 1024 * 1024,
      );
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'webtoon renders prepared next pages immediately without another fetch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final source = FixturePageSource();
      await mount(
        tester,
        OpenReader(readerManifest(count: 30), source, ReaderLocator(0)),
        const ReadingSettings(mode: ReadingMode.webtoon),
        [],
      );
      await settleReaderImages(tester);
      final prepared = source.requests.map((key) => key.pageIndex).toSet();
      expect(prepared, containsAll([0, 1, 2, 3]));
      source.hold = true; // Any newly mounted page cannot become ready during this assertion.
      final controller = tester
          .widget<ListView>(find.byKey(const Key('webtoon-reader')))
          .controller!;
      controller.jumpTo(1170);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('page-image-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-image-3')), findsOneWidget);
      for (final page in tester.widgetList<ReaderPageImage>(
        find.byType(ReaderPageImage),
      )) {
        if (page.visible) expect(prepared, contains(page.index));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'changing visible strip count keeps the existing decoded frame and dimensions',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final manifest = readerManifest(
        dimensions: [
          PageDimensions(2000, 4000),
          for (var i = 0; i < 8; i++) PageDimensions(2000, 1000),
        ],
      );
      await mount(
        tester,
        OpenReader(manifest, FixturePageSource(), ReaderLocator(0)),
        const ReadingSettings(mode: ReadingMode.webtoon),
        [],
      );
      await settleReaderImages(tester);
      final image = find.byKey(const ValueKey('page-image-0'));
      final before = tester.widget<Image>(image).image as ReaderImageProvider;
      final frame = tester
          .widget<RawImage>(
            find.descendant(of: image, matching: find.byType(RawImage)),
          )
          .image;
      final controller = tester
          .widget<ListView>(find.byKey(const Key('webtoon-reader')))
          .controller!;
      controller.jumpTo(150); // Visible count changes from two to three while page zero remains visible.
      await tester.pump();
      final after = tester.widget<Image>(image).image as ReaderImageProvider;
      expect(after.imageKey, before.imageKey);
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: image, matching: find.byType(RawImage)),
            )
            .image,
        same(frame),
      );
      expect(frame, isNotNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'prepared webtoon requests retain speculative priority until they enter the screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final source = PreparedPageSource()..hold = true;
      await mount(
        tester,
        OpenReader(readerManifest(count: 30), source, ReaderLocator(0)),
        const ReadingSettings(mode: ReadingMode.webtoon),
        [],
      );
      await tester.pump();
      expect(source.visibleRequests.map((key) => key.pageIndex), [0, 1]);
      expect(
        source.speculativeRequests.map((key) => key.pageIndex),
        containsAll([2, 3]),
      );
      tester
          .widget<ListView>(find.byKey(const Key('webtoon-reader')))
          .controller!
          .jumpTo(1170);
      await tester.pump();
      expect(
        source.visibleRequests.map((key) => key.pageIndex),
        containsAll([2, 3]),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
