import 'dart:ui' show FrameTiming;
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/ebook_reader_screen.dart';

import '../test/support/connection_fakes.dart';
import '../test/support/reader_fakes.dart';
import 'support/large_pdf_fixture.dart';
import 'support/ui_fixture_binding.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (ready()) return;
  }
  fail('Large PDF operation exceeded 60 seconds');
}

void main() {
  final binding = UiFixtureIntegrationBinding()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    '500-page image-heavy PDF navigation, search, reopen and 30-minute RSS',
    (tester) async {
      const seconds = int.fromEnvironment(
        'PDF_SOAK_SECONDS',
        defaultValue: 1800,
      );
      final directory = await Directory(
        '${(await getTemporaryDirectory()).path}/large-pdf-qa',
      ).create(recursive: true);
      final db = AppDatabase(NativeDatabase.memory());
      final assets = ReaderAssetStore(
        db,
        Directory('${directory.path}/cache'),
        Directory('${directory.path}/downloads'),
      );
      final original = File('${directory.path}/large.pdf');
      final size = await createLargePdf(original.path);
      expect(size, greaterThan(100 * 1024 * 1024));
      expect(size, lessThanOrEqualTo(512 * 1024 * 1024));
      final manifest = ReaderManifest(
        accountId: 'large-pdf-qa',
        bookId: 'large-pdf',
        revision: 'synthetic-v1',
        title: 'Inkora 500-page PDF',
        documentType: 'application/pdf',
        pages: [
          for (var i = 0; i < 500; i++)
            PageDimensions(768, 1152, sizeBytes: i == 0 ? size : 0),
        ],
      );
      final verified = await inspectDownloadAsset(
        original,
        'application/pdf',
        maximumBytes: manifest.maximumAssetBytes,
      );
      await assets.installVerifiedDownload(manifest, {
        0: verified,
      }, CancellationController());
      await original.delete();
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((_) => throw StateError('Large PDF must stay offline')),
      );
      final store = ReaderStore(db, manifest.accountId);
      final repo = ReaderRepository(
        store,
        assets,
        client,
        PageNetworkGate(),
        isCurrent: () => true,
      );
      Future<void> open(ReaderLocator locator) => tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: InkoraTheme.dark(amoled: true),
            home: EbookReaderScreen(
              reader: OpenReader(
                manifest,
                FixturePageSource(),
                locator,
                offline: true,
              ),
              repository: repo,
              settings: const ReadingSettings(mode: ReadingMode.ebook),
            ),
          ),
        ),
      );
      PdfViewerController controller() =>
          tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;
      Future<void> ready(int page) => waitFor(
        tester,
        () =>
            tester.any(find.byType(PdfViewer)) &&
            controller().isReady &&
            controller().pageNumber == page,
      );
      await open(ReaderLocator(0));
      await ready(1);
      expect(controller().document.pages, hasLength(500));
      // Search scans the complete document and must reach its final text layer.
      await tester.tapAt(tester.getCenter(find.byType(EbookReaderScreen)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('reader-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search in book'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'LANTERN00500');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await waitFor(tester, () => tester.any(find.text('Page 500')));
      await tester.tap(find.text('Page 500'));
      await ready(500);
      await tester.pump(const Duration(milliseconds: 700));
      final saved = await store.locator(manifest);
      expect(saved.pageIndex, 499);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await open(saved);
      await ready(500);
      if (const bool.fromEnvironment('PDF_VISUAL_CHECK')) {
        for (final page in [1, 250, 500]) {
          await controller().goToPage(
            pageNumber: page,
            duration: Duration.zero,
          );
          await tester.pump(const Duration(seconds: 3));
          debugPrint('PDF_VISUAL_READY: $page');
          await tester.pump(const Duration(seconds: 6));
        }
      }
      // Fill the working set before the measured interval.
      for (var i = 0; i < 50; i++) {
        await controller().goToPage(
          pageNumber: 1 + i * 7,
          duration: Duration.zero,
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      for (var i = 0; i < 10; i++) {
        await controller().setZoom(
          controller().centerPosition,
          controller().currentZoom * 1.5,
          duration: Duration.zero,
        );
        await tester.pump(const Duration(milliseconds: 200));
        final matrix = controller().calcMatrixForFit(
          pageNumber: controller().pageNumber!,
        );
        if (matrix != null) controller().value = matrix;
        await tester.pump(const Duration(milliseconds: 200));
      }
      final rss = <Map<String, num>>[];
      final elapsed = Stopwatch()..start();
      final histogram = List<int>.filled(1001, 0);
      var frames = 0, overBudget = 0;
      final budgetUs =
          1000000 / binding.platformDispatcher.views.first.display.refreshRate;
      void timings(List<FrameTiming> values) {
        for (final frame in values) {
          final us = math.max(
            frame.buildDuration.inMicroseconds,
            frame.rasterDuration.inMicroseconds,
          );
          histogram[(us / 1000).floor().clamp(0, 1000)]++;
          frames++;
          if (us > budgetUs) overBudget++;
        }
      }

      binding.addTimingsCallback(timings);
      void sample() => rss.add({
        'seconds': elapsed.elapsedMilliseconds / 1000,
        'bytes': ProcessInfo.currentRss,
      });
      sample();
      var turns = 0;
      debugPrint('PDF_SOAK_READY: $size bytes, 500 pages, $seconds seconds');
      try {
        while (elapsed.elapsed.inSeconds < seconds) {
          final page = 1 + (turns * 3 + 37) % 500;
          await controller().goToPage(
            pageNumber: page,
            duration: Duration.zero,
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller().pageNumber, page);
          if (turns % 15 == 0) {
            final zoom = controller().currentZoom;
            await controller().setZoom(
              controller().centerPosition,
              zoom * 1.5,
              duration: Duration.zero,
            );
            await tester.pump(const Duration(milliseconds: 200));
            await controller().setZoom(
              controller().centerPosition,
              zoom,
              duration: Duration.zero,
            );
          }
          await tester.pump(const Duration(milliseconds: 1800));
          turns++;
          if (turns % 5 == 0) sample();
        }
        sample();
      } finally {
        binding.removeTimingsCallback(timings);
      }
      final baseline = rss.first['bytes']!.toDouble();
      final finalRss =
          rss
              .skip(math.max(0, rss.length - 5))
              .map((s) => s['bytes']!.toDouble())
              .reduce((a, b) => a + b) /
          math.min(5, rss.length);
      final growth = (finalRss - baseline) / baseline;
      var cumulative = 0, p95 = 0;
      for (var i = 0; i < histogram.length; i++) {
        cumulative += histogram[i];
        if (cumulative >= frames * .95) {
          p95 = i;
          break;
        }
      }
      binding.reportData = {
        'framePolicy': 'fullyLive',
        'startedAtEpochMs':
            DateTime.now().millisecondsSinceEpoch - elapsed.elapsedMilliseconds,
        'fileBytes': size,
        'pages': 500,
        'durationSeconds': elapsed.elapsedMilliseconds / 1000,
        'turns': turns,
        'rss': rss,
        'rssGrowth': growth,
        'frames': frames,
        'overFrameBudget': overBudget,
        'frameBudgetUs': budgetUs,
        'buildRasterMaxP95UpperMs': p95 + 1,
        'searchLastPage': true,
        'reopenLastPage': true,
      };
      debugPrint(
        'PDF_SOAK_COMPLETE: RSS growth ${(growth * 100).toStringAsFixed(2)}%, turns $turns',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      repo.close();
      client.close();
      await db.close();
      await directory.delete(recursive: true);
      expect(
        growth,
        lessThanOrEqualTo(.1),
        reason: 'RSS must not grow by more than 10% after warmup',
      );
    },
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
