import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../support/catalogue_fakes.dart';
import '../support/connection_fakes.dart';
import '../support/reader_widget_support.dart';
import '../support/ui_harness.dart';
import '../support/catalogue_artwork.dart';
import '../support/reader_preferences.dart';
import '../support/onboarding_visuals.dart' show chooseSetupMode;

Future<void> _loadFonts() async {
  for (final (family, asset) in [
    ('LibreBaskerville', 'assets/fonts/LibreBaskerville.ttf'),
    ('PhosphorRegular', 'assets/icons/Phosphor-Regular.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk == null) {
    throw StateError('Set FLUTTER_ROOT to the pinned Flutter SDK.');
  }
  final directory =
      '$sdk/bin/cache/dart-sdk/bin/resources/devtools/assets/'
      'packages/devtools_app_shared/fonts/Roboto';
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(
      File('$directory/Roboto-$weight.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}

/// Original geometric artwork for the fictional demonstration catalogue.

void main() {
  testWidgets(
    'capture English public app screenshots with demonstration content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final artwork = <String, Uint8List>{};
      late Directory temporary;
      await tester.runAsync(() async {
        await _loadFonts();
        temporary = await Directory.systemTemp.createTemp(
          'inkora-screenshots-',
        );
        for (var index = 0; index < demonstrationTitles.length; index++) {
          final bytes = await demonstrationCover(index);
          artwork['series-$index'] = bytes;
          artwork['book-$index'] = bytes;
          for (
            var copy = index + demonstrationTitles.length;
            copy < 24;
            copy += demonstrationTitles.length
          ) {
            artwork['series-$copy'] = bytes;
          }
          artwork['demo-volume-${index + 2}'] = bytes;
        }
      });
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((request) {
          final id = request.uri.pathSegments.reversed.skip(1).first;
          return ResponseBody.fromBytes(
            artwork[id] ?? artwork['series-0']!,
            200,
            headers: {
              'content-type': ['image/png'],
            },
          );
        }),
      );
      final covers = CoverRepository(
        client,
        PageNetworkGate(),
        temporary,
        savedSession.accountId,
      );
      final series = [
        for (var index = 0; index < 24; index++)
          CatalogueItem(
            kind: CatalogueKind.series,
            id: 'series-$index',
            title: demonstrationTitles[index],
            libraryId: index.isEven ? 'library-a' : 'library-b',
            itemCount: 4 + index,
            modified: 1792015200000 + index,
            summary: 'A city that only wakes after midnight. When a young cartographer discovers a street missing from every map, a quiet commission becomes a journey through forgotten stories and impossible places. Each new route leads to another neighbourhood, another keeper of a forgotten story, and a choice between the map she was given and the city she can see. As dawn approaches, she must decide which paths to preserve and which ones to leave behind. A story of friendship, wandering and finding a place to call home.',
            metadata: CatalogueMetadata(
              publisher: 'Northlight Press',
              authors: const [
                CatalogueAuthor('Alex Rowan', 'writer'),
                CatalogueAuthor('Jamie Vale', 'penciller'),
              ],
              language: 'en',
              tags: const ['Demonstration'],
              links: const [
                CatalogueLink('Northlight Press', 'https://example.test/books'),
              ],
              status: index.isEven ? 'ONGOING' : 'ENDED',
              genres: [index.isEven ? 'Adventure' : 'Fantasy'],
            ),
          ),
      ];
      final books = [
        for (var index = 0; index < demonstrationTitles.length; index++)
          CatalogueItem(
            kind: CatalogueKind.book,
            id: 'book-$index',
            title: index == 7
                ? demonstrationTitles[index]
                : '${demonstrationTitles[index]} · Volume ${index + 1}',
            summary: 'A lighthouse keeper receives letters from an island that vanished a century ago. Follow the tide through a story of maps, memory and the places we call home.',
            metadata: CatalogueMetadata(
              mediaType: index == 7
                  ? 'application/epub+zip'
                  : 'application/zip',
              authors: const [CatalogueAuthor('Alex Rowan', 'writer')],
            ),
            libraryId: series[index].libraryId,
            seriesId: series[index].id,
            number: index + 1,
            pageCount: 192,
            readingStatus: index < 3
                ? ReadingStatus.inProgress
                : ReadingStatus.unread,
            modified: series[index].modified,
          ),
      ];
      final volumes = [
        for (var number = 2; number <= 4; number++)
          CatalogueItem(
            kind: CatalogueKind.book,
            id: 'demo-volume-$number',
            title: '${demonstrationTitles.first} · Volume $number',
            libraryId: 'library-a',
            seriesId: 'series-0',
            number: number.toDouble(),
            readingStatus: number == 2
                ? ReadingStatus.completed
                : ReadingStatus.unread,
            pageCount: 192,
          ),
      ];
      await tester.runAsync(() async {
        for (final item in [...series, ...books, ...volumes]) {
          final bytes = await covers.load((
            kind: item.kind.name,
            id: item.id,
            modified: item.modified,
          ), CancellationController());
          expect(bytes, isNotNull);
        }
      });
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(
          locale: 'en',
          appearance: AppAppearance.ocean,
          reduceMotion: true,
        ),
        covers: covers,
        resumeEntries: [
          for (final index in [0, 1, 2])
            ResumeEntry(
              item: books[index],
              seriesTitle: series[index].title,
              pageIndex: [68, 26, 112][index],
              pageCount: 192,
              fraction: 0,
            ),
        ],
        catalogue: [
          entry('library-a', kind: CatalogueKind.library, title: 'Manga'),
          entry('library-b', kind: CatalogueKind.library, title: 'Comics'),
          ...series,
          ...books,
          ...volumes,
        ],
      );
      addTearDown(() async {
        await harness.close(tester);
        await tester.runAsync(() async {
          await covers.flush();
          covers.close();
          client.close();
          await temporary.delete(recursive: true);
        });
      });
      const key = Key('public-screenshot');
      await harness.mount(tester, captureKey: key);
      Future<void> capture(String filename, {bool public = true}) async {
        await settleReaderImages(tester);
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            public
                ? 'docs/screenshots/$filename.png'
                : 'artifacts/app-chrome/$filename.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.text('Continue reading'), findsOneWidget);
      await capture('phone-home');
      final router = harness.container.read(routerProvider);
      await tester.tap(find.byKey(const Key('catalogue-floating-library')));
      await tester.pumpAndSettle();
      await capture('phone-library-picker');
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue-floating-filters')));
      await tester.pumpAndSettle();
      await capture('phone-filters');
      router.pop();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -560),
      );
      await tester.pumpAndSettle();
      await capture('phone-library');
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      await capture('phone-appearance');
      final metadataHeading = find.text('Visible metadata');
      await tester.scrollUntilVisible(metadataHeading, 300);
      await tester.ensureVisible(metadataHeading);
      final phoneMetadataScroll = Scrollable.of(tester.element(metadataHeading))
          .position;
      phoneMetadataScroll.jumpTo(
        (phoneMetadataScroll.pixels - 24).clamp(
          0,
          phoneMetadataScroll.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
      await capture('phone-metadata');
      router.go('/settings');
      await tester.pumpAndSettle();
      await capture('phone-settings');
      router.go('/settings/servers');
      await tester.pumpAndSettle();
      await capture('phone-servers');
      router.go('/settings/gestures');
      await tester.pumpAndSettle();
      await chooseGesturePreset(tester, 'custom');
      await tester.drag(
        find.byKey(const Key('ink-sheet-handle')),
        const Offset(0, -844),
      );
      await tester.pumpAndSettle();
      await capture('phone-gestures');
      router.pop();
      await tester.pumpAndSettle();
      router.go('/settings/transfer');
      await tester.pumpAndSettle();
      await capture('phone-transfer');
      router.go('/settings/quality');
      await tester.pumpAndSettle();
      await capture('phone-quality');
      router.go('/catalogue/book/book-7');
      await tester.pumpAndSettle();
      await capture('phone-ebook');
      router.go('/catalogue/series/series-0');
      await tester.pumpAndSettle();
      await capture('phone-series');
      // The series download action opens confirmation; cancel preserves fixtures.
      await tester.tap(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      await capture('phone-batch-download');
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await capture('phone-series-about');
      final preferences = UiPreferencesStore(harness.database);
      await tester.runAsync(
        () => preferences.update(
          (p) => p.copyWith(setupCompleted: false, setupStep: 3),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();
      await chooseSetupMode(tester, 'manga');
      FocusManager.instance.primaryFocus?.unfocus();
      Scrollable.of(
        tester.element(find.byKey(const Key('reader-mode-selector'))),
      ).position.jumpTo(0);
      await tester.pumpAndSettle();
      await capture('phone-setup-library');
      await tester.runAsync(
        () => preferences.update(
          (p) => p.copyWith(setupCompleted: true, setupStep: 0),
        ),
      );
      router.go('/');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 900);
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Download selected ({0})'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
      await capture('tablet-home');
      await tester.tap(find.byKey(const Key('catalogue-floating-filters')));
      await tester.pumpAndSettle();
      await capture('tablet-filters');
      router.pop();
      await tester.pumpAndSettle();
      router.go('/settings');
      await tester.pumpAndSettle();
      await capture('tablet-settings');
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      // The category is one mounted group; ensureVisible uses its own pane.
      await tester.ensureVisible(metadataHeading);
      final tabletMetadataScroll = Scrollable.of(
        tester.element(metadataHeading),
      ).position;
      tabletMetadataScroll.jumpTo(
        (tabletMetadataScroll.pixels - 24).clamp(
          0,
          tabletMetadataScroll.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
      await capture('tablet-metadata');
      router.go('/catalogue/series/series-0');
      await tester.pumpAndSettle();
      await capture('tablet-series');
      await tester.tap(find.byKey(const Key('volume-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('volume-tile-demo-volume-3')));
      await tester.tap(find.byKey(const Key('volume-tile-demo-volume-4')));
      await tester.pumpAndSettle();
      await capture('tablet-selection');
      router.go('/settings/quality');
      await tester.pumpAndSettle();
      await capture('tablet-quality');
      router.go('/');
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -850),
      );
      await tester.pumpAndSettle();
      await capture('tablet-library');
      covers.close();
      await harness.close(tester);
    },
    skip: Platform.environment['INKORA_CAPTURE_SCREENSHOTS'] != 'true',
  );
}
