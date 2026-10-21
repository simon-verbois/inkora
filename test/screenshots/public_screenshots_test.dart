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
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../support/catalogue_fakes.dart';
import '../support/connection_fakes.dart';
import '../support/reader_widget_support.dart';
import '../support/ui_harness.dart';
import '../support/catalogue_artwork.dart';

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
        }
      });
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((request) {
          final id = request.uri.pathSegments.reversed.skip(1).first;
          return ResponseBody.fromBytes(
            artwork[id]!,
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
        for (var index = 0; index < demonstrationTitles.length; index++)
          CatalogueItem(
            kind: CatalogueKind.series,
            id: 'series-$index',
            title: demonstrationTitles[index],
            libraryId: index.isEven ? 'library-a' : 'library-b',
            itemCount: 4 + index,
            modified: 1792015200000 + index,
            metadata: CatalogueMetadata(
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
            title: '${demonstrationTitles[index]} · Volume ${index + 1}',
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
      await tester.runAsync(() async {
        for (final item in [...series, ...books]) {
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
        discoveryClock: () => DateTime.utc(2026, 10, 15),
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
          for (var number = 2; number <= 4; number++)
            CatalogueItem(
              kind: CatalogueKind.book,
              id: 'demo-volume-$number',
              title: '${demonstrationTitles.first} · Volume $number',
              libraryId: 'library-a',
              seriesId: 'series-0',
              number: number.toDouble(),
              pageCount: 192,
            ),
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
      await tester.ensureVisible(find.byKey(const Key('catalogue-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue-sort')));
      await tester.pumpAndSettle();
      await capture('phone-sort-menu', public: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final router = harness.container.read(routerProvider);
      router.go('/');
      await tester.pumpAndSettle();
      final libraryControl = find.byKey(const Key('library-selector'));
      await Scrollable.ensureVisible(
        tester.element(libraryControl),
        alignment: 0,
      );
      await tester.pumpAndSettle();
      await capture('phone-library');
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      await capture('phone-appearance');
      router.go('/settings/transfer');
      await tester.pumpAndSettle();
      await capture('phone-transfer');
      router.go('/settings/quality');
      await tester.pumpAndSettle();
      await capture('phone-quality', public: false);
      await tester.tap(find.text('Upscaling'));
      await tester.pumpAndSettle();
      await capture('phone-upscaling', public: false);
      router.go('/catalogue/series/series-0');
      await tester.pumpAndSettle();
      // The series download action opens confirmation; cancel preserves fixtures.
      await tester.tap(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      await capture('phone-batch-download');
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
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
      router.go('/settings/quality');
      await tester.pumpAndSettle();
      await capture('tablet-settings-header', public: false);
      await tester.tap(find.byKey(const Key('settings-sidebar-search-toggle')));
      await tester.pumpAndSettle();
      await capture('tablet-settings-search', public: false);
      await tester.tap(find.byKey(const Key('settings-sidebar-search-toggle')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      router.go('/settings');
      await tester.pumpAndSettle();
      await capture('phone-settings', public: false);
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('panel-opacity'))),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await capture('phone-appearance-controls', public: false);
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expanded-search')), 'Atlas');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await capture('phone-search', public: false);
      router.go('/setup?edit=true');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await capture('phone-setup', public: false);
      await harness.close(tester);
    },
    skip: Platform.environment['INKORA_CAPTURE_SCREENSHOTS'] != 'true',
  );
}
