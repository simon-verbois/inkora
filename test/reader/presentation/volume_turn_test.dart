import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  for (final direction in ReadingDirection.values) {
    for (final doublePages in [false, true]) {
      testWidgets(
        'final swipe advances volume: $direction/double=$doublePages',
        (tester) async {
          tester.view.physicalSize = doublePages
              ? const Size(1024, 768)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final source = FixturePageSource();
          final navigation = ValueNotifier<ReaderLocator?>(null);
          addTearDown(navigation.dispose);
          final saved = <ReaderLocator>[];
          var ends = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ReaderViewport(
                  reader: OpenReader(
                    readerManifest(),
                    source,
                    ReaderLocator(0),
                  ),
                  settings: ReadingSettings(
                    direction: direction,
                    layout: doublePages
                        ? ReadingLayout.doublePage
                        : ReadingLayout.single,
                  ),
                  controlsVisible: false,
                  navigation: navigation,
                  onEnd: () => ends++,
                  saveLocator: (value) async => saved.add(value),
                ),
              ),
            ),
          );
          await settleReaderImages(tester);
          final view = find.byKey(const Key('paged-reader'));
          final forward = switch (direction) {
            ReadingDirection.leftToRight => Offset(
              -tester.view.physicalSize.width * .75,
              0,
            ),
            ReadingDirection.rightToLeft => Offset(
              tester.view.physicalSize.width * .75,
              0,
            ),
            ReadingDirection.vertical => Offset(
              0,
              -tester.view.physicalSize.height * .75,
            ),
          };
          // Entering the last page/spread alone must not leave the volume.
          navigation.value = ReaderLocator(doublePages ? 0 : 2);
          await settleReaderImages(tester);
          await tester.drag(view, forward);
          await settleReaderImages(tester);
          expect(saved.last.pageIndex, 3);
          expect(ends, 0);

          await tester.drag(view, forward * .05);
          await tester.drag(view, forward * -1);
          await settleReaderImages(tester);
          expect(ends, 0);
          navigation.value = ReaderLocator(3);
          await settleReaderImages(tester);
          final writesBeforeEnd = saved.length;
          final requests = source.requests.length;
          await tester.drag(view, forward);
          await settleReaderImages(tester);
          expect(ends, 1);
          expect(saved.length, writesBeforeEnd);
          expect(source.requests.length, requests);

          // Panning a zoomed final spread must never finish the book.
          final transform = tester
              .widgetList<InteractiveViewer>(find.byType(InteractiveViewer))
              .last
              .transformationController!;
          transform.value = Matrix4.diagonal3Values(2, 2, 1);
          await tester.pump();
          await tester.drag(view, forward);
          await settleReaderImages(tester);
          expect(ends, 1);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final physics in [
    const ClampingScrollPhysics(),
    const BouncingScrollPhysics(),
  ]) {
    testWidgets('PageView terminal drag advances once with $physics', (
      tester,
    ) async {
      var ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: physics,
          ),
          home: Scaffold(
            body: ReaderViewport(
              reader: OpenReader(
                readerManifest(count: 1),
                FixturePageSource(),
                ReaderLocator(0),
              ),
              settings: const ReadingSettings(layout: ReadingLayout.single),
              controlsVisible: false,
              onEnd: () => ends++,
              saveLocator: (_) async {},
            ),
          ),
        ),
      );
      await settleReaderImages(tester);
      // Exercise the scrollable's gesture path when it wins the arena over
      // InteractiveViewer, including a single-page volume.
      final position = tester
          .widget<PageView>(find.byKey(const Key('paged-reader')))
          .controller!
          .position;
      final drag = position.drag(DragStartDetails(), () {});
      for (var i = 0; i < 6; i++) {
        drag.update(
          DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: const Offset(-30, 0),
            primaryDelta: -30,
          ),
        );
        await tester.pump();
      }
      expect(ends, 0, reason: 'Handoff waits for gesture release');
      drag.end(DragEndDetails(primaryVelocity: 0));
      await settleReaderImages(tester);
      expect(ends, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
