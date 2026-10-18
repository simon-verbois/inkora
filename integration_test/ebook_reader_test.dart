import 'package:inkora/reader/presentation/ebook_presentation.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';

import 'support/ui_fixture_binding.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

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
import 'support/image_ebook_fixture.dart';

import 'package:inkora/app/widgets/image_enhancement.dart';
import 'package:inkora/core/images/image_enhancement.dart';

Future<void> until(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (predicate()) return;
  }
  fail('Native ebook did not become ready within 20 seconds');
}

Future<Map<String, dynamic>> epubLayout() async {
  final raw = await EbookPresentation.channel.invokeMethod<String>('layout');
  dynamic value = jsonDecode(raw!);
  if (value is String) value = jsonDecode(value);
  return Map<String, dynamic>.from(value as Map);
}

void main() {
  final binding = UiFixtureIntegrationBinding()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  if (const bool.fromEnvironment('BOOKMARK_NATIVE_GESTURE')) {
    binding.shouldPropagateDevicePointerEvents = true;
  }
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
        const enhancementTest = bool.fromEnvironment('ENHANCEMENT_NATIVE');
        final bytes = base64Decode(
          epub
              ? (enhancementTest ? imageEpubFixtureBase64 : epubFixtureBase64)
              : pdfFixtureBase64,
        );
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
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 500));
          repo.close();
          client.close();
          await db.close();
          if (await root.exists()) await root.delete(recursive: true);
        });
        final engine = FlutterReadium();
        var ready = false;
        Locator? location;
        final status = engine.onReaderStatusChanged.listen((s) {
          if (s == ReadiumReaderStatus.ready) ready = true;
        });

        Future<void> open(
          ReaderLocator initial, {
          double margins = 1,
          String font = 'publisher',
          bool separator = false,
          bool animation = true,
          String columns = 'auto',
        }) => tester.pumpWidget(
          ProviderScope(
            overrides: [
              catalogueItemProvider((CatalogueKind.book, manifest.bookId))
                  .overrideWith((ref) => Stream.value(null)),
            ],
            child: ImageEnhancementScope(
              level: enhancementTest
                  ? ImageEnhancement.balanced
                  : ImageEnhancement.off,
              child: MaterialApp(
                theme: InkoraTheme.forest(),
                home: EbookReaderScreen(
                  reader: OpenReader(
                    manifest,
                    FixturePageSource(),
                    initial,
                    offline: true,
                  ),
                  repository: repo,
                  settings: ReadingSettings(
                    mode: ReadingMode.ebook,
                    pageAnimation: animation,
                    ebook: EbookSettings(
                      margins: margins,
                      font: font,
                      columnSeparator: separator,
                      columns: columns,
                    ),
                  ),
                ),
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
        final locations = engine.onTextLocatorChanged.listen((l) {
          location = l;
          if (const bool.fromEnvironment('BOOKMARK_NATIVE_GESTURE')) {
            debugPrint(
              'BOOKMARK_LOCATION ${l.href} ${l.locations?.progression}',
            );
          }
        });
        await tester.pump(const Duration(milliseconds: 500));
        if (epub && enhancementTest) {
          expect((await epubLayout())['enhancedImages'], greaterThan(0));
          final state = tester.state(find.byType(ReadiumReaderWidget));
          await EbookPresentation.configure(animations: true, separator: false);
          expect((await epubLayout())['enhancedImages'], 0);
          await EbookPresentation.configure(
            animations: true,
            separator: false,
            imageEnhancement: ImageEnhancement.balanced,
          );
          expect((await epubLayout())['enhancedImages'], greaterThan(0));
          expect(tester.state(find.byType(ReadiumReaderWidget)), same(state));
        }
        if (epub) {
          await open(
            ReaderLocator(0),
            columns: 'two',
            separator: true,
            animation: false,
          );
          await tester.pump(const Duration(milliseconds: 900));
          final layout = await epubLayout();
          expect(layout['columns'], '2');
          expect(layout['rule'], 'solid');
          // WebView quantizes a CSS pixel to its physical-pixel grid.
          expect(
            double.parse((layout['width'] as String).replaceAll('px', '')),
            allOf(greaterThan(0), lessThanOrEqualTo(1)),
          );
          expect(await EbookPresentation.turn(1, animated: false), isTrue);
          tester
                  .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
                  .shouldShowControls!
                  .value =
              true;
          await tester.pump(const Duration(milliseconds: 300));
          debugPrint('READER_UX_TWO_COLUMNS_READY');
          await tester.pump(const Duration(seconds: 2));
          tester
                  .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
                  .shouldShowControls!
                  .value =
              false;
          await tester.pump(const Duration(milliseconds: 300));
          final publicationState = tester.state(
            find.byType(ReadiumReaderWidget),
          );
          await open(
            ReaderLocator(0),
            columns: 'one',
            separator: true,
            animation: false,
          );
          await tester.pump(const Duration(milliseconds: 700));
          expect((await epubLayout())['columns'], '1');
          expect(
            tester.state(find.byType(ReadiumReaderWidget)),
            same(publicationState),
          );
          await open(ReaderLocator(0), columns: 'one', separator: false);
          await tester.pump(const Duration(milliseconds: 700));
          expect((await epubLayout())['rule'], 'none');
        }
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
        if (const bool.fromEnvironment('INPUT_LIFECYCLE')) {
          const input = MethodChannel('inkora/input_configuration');
          final before = (await input.invokeMapMethod<String, int>(
            'snapshot',
          ))!;
          final publication = tester.state(
            find.byType(epub ? ReadiumReaderWidget : PdfViewer),
          );
          final locator = await store.locator(manifest);
          debugPrint('INPUT_READY_${epub ? 'EPUB' : 'PDF'}');
          var attached = false;
          var detached = false;
          for (var attempt = 0; attempt < 300; attempt++) {
            await tester.pump(const Duration(milliseconds: 100));
            final current = (await input.invokeMapMethod<String, int>(
              'snapshot',
            ))!;
            expect(current['instance'], before['instance']);
            expect(
              tester.state(find.byType(epub ? ReadiumReaderWidget : PdfViewer)),
              same(publication),
            );
            if (current['navigation'] == 2) attached = true;
            if (attached && current['navigation'] == before['navigation']) {
              detached = true;
              break;
            }
          }
          expect(
            attached,
            isTrue,
            reason: 'Host must register the temporary DPAD keyboard',
          );
          expect(
            detached,
            isTrue,
            reason: 'Host must remove the temporary DPAD keyboard',
          );
          final after = await store.locator(manifest);
          expect(after.pageIndex, locator.pageIndex);
          expect(after.documentLocator, locator.documentLocator);
          debugPrint('INPUT_RETAINED_${epub ? 'EPUB' : 'PDF'}');
        }
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
          final screen = tester.getRect(find.byType(EbookReaderScreen));
          final surface = tester.getRect(find.byType(ReadiumReaderWidget));
          expect(surface.top - screen.top, closeTo(24, 1));
          expect(screen.bottom - surface.bottom, closeTo(24, 1));
          await open(ReaderLocator(0), margins: 2, font: 'baskerville');
          await tester.pump(const Duration(milliseconds: 900));
          final wideSurface = tester.getRect(find.byType(ReadiumReaderWidget));
          expect(wideSurface.top - screen.top, closeTo(48, 1));
          expect(screen.bottom - wideSurface.bottom, closeTo(48, 1));
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
        await tester.tap(find.byKey(const Key('reader-details')));
        await tester.pumpAndSettle();
        expect(find.text('Book details'), findsOneWidget);
        expect(find.text(manifest.title), findsWidgets);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Reading preferences'));
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
        final bookmarks = EbookBookmarks(
          db,
          manifest.accountId,
          manifest.bookId,
        );
        if (epub && const bool.fromEnvironment('BOOKMARK_NATIVE_GESTURE')) {
          // Host adb performs a real long press and taps the native menu item.
          // Keep fixtures isolated and the application installed during driving.
          await tester.tapAt(tester.getCenter(find.byType(EbookReaderScreen)));
          await tester.pump(const Duration(milliseconds: 300));
          debugPrint('BOOKMARK_SELECTION_READY');
          for (var attempt = 0; attempt < 450; attempt++) {
            await tester.pump(const Duration(milliseconds: 200));
            if ((await bookmarks.read()).isNotEmpty) break;
          }
          final selection = (await bookmarks.read()).single;
          expect(selection.excerpt, isNotEmpty);
          debugPrint('BOOKMARK_ANCHOR ${selection.encode()}');
          final textAnchor = selection.value['text'] as Map;
          expect(textAnchor['before'] ?? textAnchor['after'], isNotNull);
          expect(
            Locator.fromJson(selection.value)!.text?.highlight,
            selection.excerpt,
          );
          await open(ReaderLocator(0), margins: 1.5, font: 'sans-serif');
          await tester.pump(const Duration(milliseconds: 1000));
          expect(
            (await bookmarks.read()).single.bookmarkKey,
            selection.bookmarkKey,
          );
          debugPrint('BOOKMARK_REFLOW_READY');
          await tester.pump(const Duration(seconds: 2));
          await engine.goToLocator(
            Locator(
              href: selection.href,
              type: 'application/xhtml+xml',
              locations: const Locations(progression: .75),
            ),
          );
          await until(
            tester,
            () => (location?.locations?.progression ?? 0) > .5,
          );
        } else if (!epub) {
          final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
          final controller = viewer.controller!;
          // The synthetic PDF's second line starts at PDF (40,555).
          final documentRect = controller.calcRectForRectInsidePage(
            pageNumber: 2,
            rect: const PdfRect(42, 570, 67, 550),
          );
          final point = controller.documentToGlobal(documentRect.center)!;
          await tester.longPressAt(point);
          await until(tester, () => tester.any(find.text('Add bookmark')));
          expect(find.byKey(const Key('reader-details')), findsNothing);
          await tester.tap(find.text('Add bookmark'));
          await until(tester, () => tester.any(find.text('Bookmark added')));
          final selection = (await bookmarks.read()).single;
          expect(selection.excerpt, isNotEmpty);
          expect(selection.pdfRectangle, isNotNull);
          final native = Locator.fromJson(selection.value)!;
          expect(
            EbookLocator(Map<String, dynamic>.from(native.toJson()))
                .pdfRectangle,
            selection.pdfRectangle,
          );
          // Dismiss the confirmation so it does not cover reader controls.
          ScaffoldMessenger.of(tester.element(find.byType(PdfViewer)))
              .clearSnackBars();
          await tester.pump(const Duration(milliseconds: 400));
          await controller.goToPage(pageNumber: 3, duration: Duration.zero);
          await until(tester, () => controller.pageNumber == 3);
          final previousZoom = controller.currentZoom;
          await controller.setZoom(
            controller.centerPosition,
            previousZoom * 1.5,
            duration: Duration.zero,
          );
          expect(controller.currentZoom, greaterThan(previousZoom));
          // The selection hides chrome; reveal it after dismissing selection.
          await tester.tapAt(
            tester.getBottomRight(find.byType(PdfViewer)) -
                const Offset(24, 24),
          );
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (epub) {
          tester
                  .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
                  .shouldShowControls!
                  .value =
              true;
          await tester.pump(const Duration(milliseconds: 400));
        } else if (!tester.any(find.byTooltip('Reading controls'))) {
          await tester.tapAt(tester.getCenter(find.byType(EbookReaderScreen)));
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.tap(find.byTooltip('Bookmarks'));
        await tester.pumpAndSettle();
        final pdfBookmarkZoom = epub
            ? null
            : tester
                  .widget<PdfViewer>(find.byType(PdfViewer))
                  .controller!
                  .currentZoom;
        final preciseBookmarks = await bookmarks.read();
        final preciseCount = preciseBookmarks.length;
        if (preciseCount > 0) {
          final beforeJump = location?.locations?.progression ?? 0;
          if (epub) debugPrint('BOOKMARK_BEFORE_JUMP $beforeJump');
          await tester.tap(find.text(preciseBookmarks.first.excerpt));
          if (epub) {
            await tester.pump(const Duration(milliseconds: 700));
            debugPrint('BOOKMARK_AFTER_JUMP ${location?.toJson()}');
            await until(
              tester,
              () => (location?.locations?.progression ?? 1) < beforeJump,
            );
            expect(location!.href, contains('chapter2'));
            tester
                    .widget<ReadiumReaderWidget>(
                      find.byType(ReadiumReaderWidget),
                    )
                    .shouldShowControls!
                    .value =
                true;
          } else {
            await until(
              tester,
              () =>
                  tester
                      .widget<PdfViewer>(find.byType(PdfViewer))
                      .controller!
                      .pageNumber ==
                  2,
            );
            final controller = tester
                .widget<PdfViewer>(find.byType(PdfViewer))
                .controller!;
            expect(controller.currentZoom, closeTo(pdfBookmarkZoom!, .001));
            final rect = preciseBookmarks.first.pdfRectangle!;
            final target = controller.calcRectForRectInsidePage(
              pageNumber: 2,
              rect: PdfRect(rect[0], rect[1], rect[2], rect[3]),
            );
            expect(controller.visibleRect.contains(target.center), true);
          }
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.byTooltip('Bookmarks'));
          await tester.pumpAndSettle();
          expect(find.text(preciseBookmarks.first.excerpt), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Add bookmark'));
        await until(
          tester,
          () => tester.any(find.byTooltip('Remove bookmark')),
        );
        expect(
          await EbookBookmarks(db, manifest.accountId, manifest.bookId).read(),
          hasLength(preciseCount + 1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        await status.cancel();
        await locations.cancel();
        final resume = await store.locator(manifest);
        if (!epub) expect(resume.pageIndex, 1);
        await open(resume);
        expect(await bookmarks.read(), hasLength(preciseCount + 1));
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
      },
    );
  }
}
