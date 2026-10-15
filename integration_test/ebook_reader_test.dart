import 'package:pdfrx/pdfrx.dart';

import 'support/ui_fixture_binding.dart';

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_readium/flutter_readium.dart' hide ReadingProgression;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/ebook_bookmarks.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/presentation/ebook_reader_screen.dart';

import '../test/support/connection_fakes.dart';
import '../test/support/reader_fakes.dart';
import 'support/ebook_fixtures.dart';

Future<void> until(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (predicate()) return;
  }
  fail('Native ebook did not become ready within 20 seconds');
}

void main() {
  UiFixtureIntegrationBinding().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  for (final epub in [true, false]) {
    testWidgets(
      'local ${epub ? "EPUB" : "PDF"} opens, navigates, searches and persists position',
      (tester) async {
        final support = await getTemporaryDirectory();
        final root = await Directory('${support.path}/ebook-native-fixture')
            .create(recursive: true);
        final db = AppDatabase(NativeDatabase.memory());
        final assets = ReaderAssetStore(
          db,
          Directory('${root.path}/cache'),
          Directory('${root.path}/downloads'),
        );
        final bytes = base64Decode(epub ? epubFixtureBase64 : pdfFixtureBase64);
        final positions = epub
            ? (jsonDecode(epubPositionsJson)['positions'] as List)
                  .map((p) => Map<String, dynamic>.from(p as Map))
                  .toList()
            : <Map<String, dynamic>>[];
        final manifest = ReaderManifest(
          accountId: 'synthetic-account',
          bookId: epub ? 'epub-fixture' : 'pdf-fixture',
          revision: epub ? 'epub-r1' : 'pdf-r1',
          title: epub ? 'Inkora EPUB fixture' : 'Inkora PDF fixture',
          documentType: epub ? 'application/epub+zip' : 'application/pdf',
          positions: positions,
          pages: [
            for (var i = 0; i < (epub ? positions.length : 3); i++)
              PageDimensions(1, 1, sizeBytes: i == 0 ? bytes.length : 0),
          ],
        );
        final file = File('${root.path}/fixture.${epub ? "epub" : "pdf"}');
        await file.writeAsBytes(bytes);
        final asset = await inspectDownloadAsset(file, manifest.documentType!);
        await assets.installVerifiedDownload(manifest, {
          0: asset,
        }, CancellationController());
        final client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          FixtureAdapter(
            (_) => throw StateError(
              'Offline native reader must not request the network',
            ),
          ),
        );
        final store = ReaderStore(db, 'synthetic-account');
        final repo = ReaderRepository(
          store,
          assets,
          client,
          PageNetworkGate(),
          isCurrent: () => true,
        );
        final engine = FlutterReadium();
        var ready = false;
        Locator? location;
        final status = engine.onReaderStatusChanged.listen((s) {
          if (s == ReadiumReaderStatus.ready) ready = true;
        });

        Future<void> open(ReaderLocator initial) => tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: EbookReaderScreen(
                reader: OpenReader(
                  manifest,
                  FixturePageSource(),
                  initial,
                  offline: true,
                ),
                repository: repo,
                settings: const ReadingSettings(mode: ReadingMode.ebook),
              ),
            ),
          ),
        );
        await open(ReaderLocator(0));
        await until(
          tester,
          () => epub
              ? ready
              : tester.any(find.byType(PdfViewer)) &&
                    tester
                        .widget<PdfViewer>(find.byType(PdfViewer))
                        .controller!
                        .isReady &&
                    tester
                            .widget<PdfViewer>(find.byType(PdfViewer))
                            .controller!
                            .pageNumber !=
                        null,
        );
        expect(find.textContaining('Unable to open'), findsNothing);
        final locations = engine.onTextLocatorChanged.listen(
          (l) => location = l,
        );
        await tester.pump(const Duration(milliseconds: 500));
        if (epub) {
          await engine.goForward();
        } else {
          await tester
              .widget<PdfViewer>(find.byType(PdfViewer))
              .controller!
              .goToPage(pageNumber: 2, duration: Duration.zero);
        }
        await until(
          tester,
          () => epub
              ? location != null && (location!.locations?.progression ?? 0) > 0
              : tester
                        .widget<PdfViewer>(find.byType(PdfViewer))
                        .controller!
                        .pageNumber ==
                    2,
        );
        await tester.pump(const Duration(milliseconds: 700));
        if (!epub) {
          for (var attempt = 0; attempt < 30; attempt++) {
            if ((await store.locator(manifest)).pageIndex == 1) break;
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        final saved = await store.locator(manifest);
        if (epub) {
          expect(saved.documentLocator, isNotNull);
        } else {
          expect(saved.pageIndex, 1);
        }
        if (!epub) {
          final controller = tester
              .widget<PdfViewer>(find.byType(PdfViewer))
              .controller!;
          final initialZoom = controller.currentZoom;
          await controller.setZoom(
            controller.centerPosition,
            initialZoom * 1.5,
            duration: Duration.zero,
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(controller.currentZoom, greaterThan(initialZoom));
          await controller.setZoom(
            controller.centerPosition,
            initialZoom,
            duration: Duration.zero,
          );
        }
        if (epub) {
          await tester.tapAt(tester.getCenter(find.byType(EbookReaderScreen)));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byTooltip('Table of contents'), findsOneWidget);
          await tester.tap(find.byTooltip('Table of contents'));
          await tester.pumpAndSettle();
          expect(find.text('Second chapter'), findsOneWidget);
          await tester.tap(find.text('Second chapter'));
          await until(
            tester,
            () => location?.href.contains('chapter2') ?? false,
          );
          await engine.setEPUBPreferences(
            const EPUBPreferences(fontSize: 1.6, lineHeight: 1.8),
          );
          await tester.pump(const Duration(milliseconds: 700));
          expect(location!.href, contains('chapter2'));
        }
        if (epub) {
          final results = await engine.searchInPublication('lantern');
          expect(results, isNotEmpty);
        } else {
          await tester.tapAt(tester.getCenter(find.byType(EbookReaderScreen)));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Search in book'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'lantern');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await until(
            tester,
            () =>
                tester.any(find.textContaining('The lantern lights the path.')),
          );
        }
        if (!epub) {
          Navigator.of(tester.element(find.byType(TextField))).pop();
          await tester.pumpAndSettle();
        }
        // Exercise the production modal above the native publication surface.
        await tester.tap(find.byTooltip('Reading controls'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reading preferences'));
        await tester.pumpAndSettle();
        expect(find.text('Typography'), epub ? findsOneWidget : findsNothing);
        if (epub) {
          await tester.tap(find.text('Typography'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('ebook-fontSize')), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(
          find.byType(epub ? ReadiumReaderWidget : PdfViewer),
          findsOneWidget,
        );
        expect(await db.select(db.readingPreferences).get(), isEmpty);
        await tester.tap(find.byTooltip('Reading controls'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bookmarks'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add bookmark'));
        await until(
          tester,
          () => tester.any(find.byTooltip('Remove bookmark')),
        );
        expect(
          await EbookBookmarks(db, manifest.accountId, manifest.bookId).read(),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        await status.cancel();
        await locations.cancel();
        final resume = await store.locator(manifest);
        if (!epub) expect(resume.pageIndex, 1);
        await open(resume);
        await until(
          tester,
          () => epub
              ? tester.any(find.byType(ReadiumReaderWidget))
              : tester.any(find.byType(PdfViewer)) &&
                    tester
                        .widget<PdfViewer>(find.byType(PdfViewer))
                        .controller!
                        .isReady &&
                    tester
                            .widget<PdfViewer>(find.byType(PdfViewer))
                            .controller!
                            .pageNumber ==
                        resume.pageIndex + 1,
        );
        if (epub) {
          await tester.pump(const Duration(milliseconds: 800));
          Locator? restored;
          final resumedLocations = engine.onTextLocatorChanged.listen(
            (l) => restored = l,
          );
          await engine.goForward();
          await until(tester, () => restored != null);
          expect(restored!.href, contains('chapter2'));
          await resumedLocations.cancel();
        } else {
          expect(
            tester
                .widget<PdfViewer>(find.byType(PdfViewer))
                .controller!
                .pageNumber,
            2,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        repo.close();
        client.close();
        await db.close();
        await root.delete(recursive: true);
      },
    );
  }
}
