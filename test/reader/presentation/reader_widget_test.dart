import 'package:inkora/app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
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
    'rotation refits the viewport and clears the previous zoom without moving pages',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(768, 1024);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final reader = OpenReader(
        readerManifest(),
        FixturePageSource(),
        ReaderLocator(0),
      );
      final saved = <ReaderLocator>[];
      await mount(
        tester,
        reader,
        const ReadingSettings(layout: ReadingLayout.single),
        saved,
      );
      await settleReaderImages(tester);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
          .transformationController!;
      controller.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), 2);
      tester.view.physicalSize = const Size(1024, 768);
      await settleReaderImages(tester);
      expect(controller.value.getMaxScaleOnAxis(), 1);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('page-image-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final direction in ReadingDirection.values) {
    testWidgets(
      'paged reader restores and navigates first/last pages in ${direction.name}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final manifest = readerManifest(count: 3);
        final remote = FixturePageSource();
        final saved = <ReaderLocator>[];
        final reader = OpenReader(manifest, remote, ReaderLocator(1));
        await mount(
          tester,
          reader,
          ReadingSettings(direction: direction),
          saved,
        );
        await settleReaderImages(tester);
        expect(find.text('2 / 3'), findsOneWidget);
        expect(find.byKey(const ValueKey('page-image-1')), findsOneWidget);
        await tester.tap(find.byTooltip('Next page'));
        await settleReaderImages(tester);
        expect(find.text('3 / 3'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, InkIcons.caretRight),
              )
              .onPressed,
          isNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await settleReaderImages(tester);
        expect(find.text('1 / 3'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, InkIcons.caretLeft),
              )
              .onPressed,
          isNull,
        );
        expect(saved.map((p) => p.pageIndex), containsAll([2, 0]));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('RTL swipes preserve logical order and zoom disables paging', (
    tester,
  ) async {
    final reader = OpenReader(
      readerManifest(),
      FixturePageSource(),
      ReaderLocator(0),
    );
    await mount(
      tester,
      reader,
      const ReadingSettings(
        direction: ReadingDirection.rightToLeft,
        layout: ReadingLayout.single,
      ),
      [],
    );
    await settleReaderImages(tester);
    await tester.drag(
      find.byKey(const Key('paged-reader')),
      const Offset(600, 0),
    );
    await settleReaderImages(tester);
    expect(find.text('2 / 4'), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    expect(
      tester.widget<PageView>(find.byKey(const Key('paged-reader'))).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    viewer.transformationController!.value = Matrix4.identity();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'landscape tablet spreads show stable page indexes and preserve page when returning to portrait',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 768);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final reader = OpenReader(
        readerManifest(),
        FixturePageSource(),
        ReaderLocator(2),
      );
      await mount(tester, reader, const ReadingSettings(spreads: true), []);
      await settleReaderImages(tester);
      expect(find.byKey(const ValueKey('page-image-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-image-3')), findsOneWidget);
      tester.view.physicalSize = const Size(768, 1024);
      await settleReaderImages(tester);
      expect(find.text('3 / 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('page-image-2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'webtoon uses viewport-relative lazy demand and restores normalized position through resize and mode changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final manifest = readerManifest(count: 100);
      final source = FixturePageSource();
      final saved = <ReaderLocator>[];
      final reader = OpenReader(manifest, source, ReaderLocator(40, .35));
      await mount(
        tester,
        reader,
        const ReadingSettings(mode: ReadingMode.webtoon),
        saved,
      );
      await settleReaderImages(tester);
      expect(find.text('41 / 100'), findsOneWidget);
      expect(source.requests.length, lessThanOrEqualTo(12));
      expect(
        source.requests.every((k) => k.pageIndex >= 36 && k.pageIndex <= 46),
        isTrue,
      );
      await tester.drag(
        find.byKey(const Key('webtoon-reader')),
        const Offset(0, -250),
      );
      await settleReaderImages(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final before = saved.last;
      tester.view.physicalSize = const Size(768, 1024);
      await settleReaderImages(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final after = saved.last;
      expect(after.pageIndex, before.pageIndex);
      expect(after.fraction, closeTo(before.fraction, .005));
      await mount(tester, reader, const ReadingSettings(), saved);
      await settleReaderImages(tester);
      expect(find.text('${after.pageIndex + 1} / 100'), findsOneWidget);
      await mount(
        tester,
        reader,
        const ReadingSettings(mode: ReadingMode.webtoon),
        saved,
      );
      await settleReaderImages(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'leaving a pending page cancels fetch and offline page errors can retry',
    (tester) async {
      final source = FixturePageSource()..hold = true;
      final manifest = readerManifest(count: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 500,
            child: ReaderPageImage(
              manifest: manifest,
              index: 0,
              source: source,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(source.cancelled, [manifest.key(0)]);
      source.hold = false;
      source.offline = true;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 500,
            child: ReaderPageImage(
              manifest: manifest,
              index: 0,
              source: source,
            ),
          ),
        ),
      );
      await settleReaderImages(tester);
      expect(find.text('Offline'), findsOneWidget);
      source.offline = false;
      await tester.tap(find.text('Retry page'));
      await settleReaderImages(tester);
      expect(find.byKey(const ValueKey('page-image-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rapid webtoon fling and reversal cancel obsolete visible demand',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixturePageSource()..hold = true;
      final reader = OpenReader(
        readerManifest(count: 200),
        source,
        ReaderLocator(50),
      );
      await mount(
        tester,
        reader,
        const ReadingSettings(mode: ReadingMode.webtoon),
        [],
      );
      await tester.pump();
      await tester.fling(
        find.byKey(const Key('webtoon-reader')),
        const Offset(0, -900),
        5000,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.fling(
        find.byKey(const Key('webtoon-reader')),
        const Offset(0, 900),
        5000,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(source.cancelled, isNotEmpty);
      expect(source.requests.length, lessThan(30));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(source.cancelled.length, source.requests.length);
    },
  );
}
