import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/presentation/reader_system_ui.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  for (final mode in ReadingMode.values) {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      testWidgets(
        '$mode reader tap toggles fullscreen overlays without moving pages at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final calls = <bool>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            ReaderSystemUi.channel,
            (call) async {
              calls.add(call.arguments as bool);
              return true;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(ReaderSystemUi.channel, null),
          );
          final manifest = readerManifest(count: 10);
          final container = ProviderContainer(
            overrides: [
              openReaderProvider(manifest.bookId).overrideWith(
                (ref) async => OpenReader(
                  manifest,
                  FixturePageSource(),
                  ReaderLocator(1, .2),
                ),
              ),
              readingSettingsProvider(manifest.bookId).overrideWith(
                (ref) => Stream.value(ReadingSettings(mode: mode)),
              ),
              readerRepositoryProvider.overrideWith((ref) async => null),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(home: ReaderScreen(bookId: manifest.bookId)),
            ),
          );
          await settleReaderImages(tester);
          final viewport = find.byType(ReaderViewport);
          final originalState = tester.state(viewport);
          final rect = tester.getRect(viewport);
          double position() => mode == ReadingMode.webtoon
              ? tester
                    .widget<ListView>(find.byKey(const Key('webtoon-reader')))
                    .controller!
                    .offset
              : tester
                    .widget<PageView>(find.byKey(const Key('paged-reader')))
                    .controller!
                    .page!;
          final initial = position();
          expect(find.byType(AppBar), findsNothing);
          expect(find.byKey(const Key('reader-page-slider')), findsNothing);
          expect(calls, [true]);
          // An edge tap reveals controls instead of changing the page.
          await tester.tapAt(Offset(20, size.height / 2));
          await settleReaderImages(tester);
          expect(find.byType(AppBar), findsOneWidget);
          final doublePages =
              mode != ReadingMode.webtoon &&
              ReadingSettings(mode: mode)
                  .useDoublePages(size.width, size.height);
          expect(
            find.text(doublePages ? '1–2 / 10' : '2 / 10'),
            findsOneWidget,
          );
          expect(tester.getRect(viewport), rect);
          expect(tester.state(viewport), same(originalState));
          expect(position(), closeTo(initial, .01));
          expect(calls.last, false);
          // Controls have their own tap handlers and do not toggle the overlay.
          await tester.tap(find.byTooltip('Next page'));
          await settleReaderImages(tester);
          expect(
            find.text(doublePages ? '3–4 / 10' : '3 / 10'),
            findsOneWidget,
          );
          expect(calls.last, false);
          final advanced = position();
          TransformationController? transform;
          if (mode != ReadingMode.webtoon) {
            transform = tester
                .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
                .transformationController!;
            transform.value = Matrix4.diagonal3Values(2, 2, 1);
            await tester.pump();
          }
          expect(find.text('Invalid image — retry page'), findsNothing);
          await tester.tapAt(tester.getCenter(viewport));
          await settleReaderImages(tester);
          expect(find.byType(AppBar), findsNothing);
          expect(find.byKey(const Key('reader-position')), findsNothing);
          expect(position(), closeTo(advanced, .01));
          expect(calls.last, true);
          if (transform != null) {
            expect(transform.value.getMaxScaleOnAxis(), 2);
            transform.value = Matrix4.identity();
            await tester.pump();
          }
          await tester.drag(
            find.byKey(
              Key(
                mode == ReadingMode.webtoon ? 'webtoon-reader' : 'paged-reader',
              ),
            ),
            mode == ReadingMode.webtoon
                ? const Offset(0, -500)
                : Offset(
                    mode == ReadingMode.manga ? size.width : -size.width,
                    0,
                  ),
          );
          await settleReaderImages(tester);
          expect(find.byType(AppBar), findsNothing);
          expect(position(), greaterThan(advanced));
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await settleReaderImages(tester);
          expect(find.byType(AppBar), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settleReaderImages(tester);
          expect(find.byType(AppBar), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await settleReaderImages(tester);
          expect(calls.last, false);
          container.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
