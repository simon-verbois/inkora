import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/raster_bookmarks.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/raster_navigation_sheet.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';
import 'package:inkora/reader/presentation/reader_chrome.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'overview is lazy and selection returns a locator at $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final source = FixturePageSource();
          final manifest = readerManifest(count: 400);
          ReaderLocator? result;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<ReaderLocator>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => RasterNavigationSheet(
                          reader: OpenReader(
                            manifest,
                            source,
                            ReaderLocator(0),
                          ),
                          bookmarks: RasterBookmarks(
                            db,
                            manifest.accountId,
                            manifest.bookId,
                          ),
                          current: ReaderLocator(0),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await settleReaderImages(tester);
          expect(source.requests.length, allOf(greaterThan(0), lessThan(40)));
          await tester.ensureVisible(find.text('Page 1/400'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Page 1/400'));
          await tester.pumpAndSettle();
          expect(result?.pageIndex, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'bookmark list returns the saved webtoon fraction and permits removal',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final manifest = readerManifest();
      final bookmarks = RasterBookmarks(
        db,
        manifest.accountId,
        manifest.bookId,
      );
      await tester.runAsync(
        () =>
            bookmarks.add(const RasterBookmark('revision-a', 2, .42, 'Scene')),
      );
      ReaderLocator? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<ReaderLocator>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RasterNavigationSheet(
                      reader: OpenReader(
                        manifest,
                        FixturePageSource(),
                        ReaderLocator(0),
                      ),
                      bookmarks: bookmarks,
                      current: ReaderLocator(0),
                      showBookmarks: true,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scene'));
      await tester.pumpAndSettle();
      expect(selected?.pageIndex, 2);
      expect(selected?.fraction, .42);
      await tester.tap(find.text('Open'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No bookmarks yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('preview is throttled and never seeks until release', (
    tester,
  ) async {
    final previews = <int>[];
    final previewTimes = <DateTime>[];
    final commits = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSeekBar(
            position: 0,
            count: 100,
            onSeek: commits.add,
            onPrevious: null,
            onNext: null,
            previewBuilder: (page) {
              previews.add(page);
              previewTimes.add(tester.binding.clock.now());
              return Text('Preview $page');
            },
          ),
        ),
      ),
    );
    final slider = find.byKey(const Key('reader-page-slider'));
    final bounds = tester.getRect(slider);
    final gesture = await tester.startGesture(
      Offset(bounds.left + 25, bounds.center.dy),
    );
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(commits, isEmpty);
    for (var i = 1; i < previewTimes.length; i++) {
      expect(
        previewTimes[i].difference(previewTimes[i - 1]),
        greaterThanOrEqualTo(const Duration(milliseconds: 150)),
      );
    }
    await tester.pump(const Duration(milliseconds: 170));
    expect(previews, isNotEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(commits, hasLength(1));
  });
  testWidgets(
    'external bookmark navigation retains viewport state and a final advance invokes handoff',
    (tester) async {
      final controller = ValueNotifier<ReaderLocator?>(null);
      addTearDown(controller.dispose);
      final saved = <ReaderLocator>[];
      var ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              reader: OpenReader(
                readerManifest(),
                FixturePageSource(),
                ReaderLocator(0),
              ),
              settings: const ReadingSettings(layout: ReadingLayout.single),
              navigation: controller,
              onEnd: () => ends++,
              saveLocator: (v) async => saved.add(v),
            ),
          ),
        ),
      );
      await settleReaderImages(tester);
      final state = tester.state(find.byType(ReaderViewport));
      controller.value = ReaderLocator(3, .42);
      await settleReaderImages(tester);
      expect(tester.state(find.byType(ReaderViewport)), same(state));
      expect(saved.last.pageIndex, 3);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pump();
      expect(ends, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
