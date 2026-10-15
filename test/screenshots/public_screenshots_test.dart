import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../support/catalogue_fakes.dart';
import '../support/connection_fakes.dart';
import '../support/reader_widget_support.dart';
import '../support/ui_harness.dart';

const _titles = [
  'Moonlit District',
  'Atlas Nine',
  'The Last Orchard',
  'Tides of Glass',
  'Paper Cities',
  'Aster & Ash',
  'Beyond the Pines',
  'Blue Meridian',
];
const _palettes = [
  [Color(0xff152c46), Color(0xffd6b778), Color(0xff4b7299)],
  [Color(0xffb74e35), Color(0xfffee1a1), Color(0xffef985c)],
  [Color(0xff243f36), Color(0xffe6d4a2), Color(0xff658467)],
  [Color(0xff184856), Color(0xffdcddb0), Color(0xff4f9da0)],
  [Color(0xff593c57), Color(0xfff2d0b0), Color(0xffa2788d)],
  [Color(0xff40333e), Color(0xfff5d3a0), Color(0xffbc7458)],
  [Color(0xff263c36), Color(0xffe0d8b9), Color(0xff6f8e72)],
  [Color(0xff1b3b68), Color(0xffe6dfc4), Color(0xff5582b3)],
];

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
Future<Uint8List> _cover(int index) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final palette = _palettes[index];
  final paint = Paint()..color = palette[0];
  canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 690), paint);
  canvas.drawCircle(
    Offset(320 - index % 3 * 65, 210 + index % 2 * 45),
    90,
    paint..color = palette[1],
  );
  // Layered terrain and a skyline create distinct covers without real books.
  for (var layer = 0; layer < 3; layer++) {
    final path = Path()..moveTo(0, 690);
    for (var x = 0; x <= 480; x += 24) {
      path.lineTo(
        x.toDouble(),
        420 + layer * 65 - math.sin(x / 90 + index + layer) * 50,
      );
    }
    path.lineTo(480, 690);
    path.close();
    canvas.drawPath(
      path,
      paint..color = Color.lerp(palette[2], palette[0], layer * .3)!,
    );
  }
  if (index.isEven) {
    for (var column = 0; column < 11; column++) {
      final height = 80.0 + (column * 47 + index * 23) % 150;
      canvas.drawRect(
        Rect.fromLTWH(column * 48.0 - 8, 565 - height, 32, height),
        paint..color = palette[0],
      );
    }
  }
  final title = TextPainter(
    text: TextSpan(
      text: _titles[index].toUpperCase(),
      style: TextStyle(
        fontFamily: 'LibreBaskerville',
        fontSize: 39,
        height: 1.13,
        color: palette[1],
        letterSpacing: 1.3,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 400);
  title.paint(canvas, const Offset(36, 36));
  title.dispose();
  final caption = TextPainter(
    text: TextSpan(
      text: 'INKORA  /  SAMPLE EDITION  0${index + 1}',
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        color: palette[1],
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 420);
  caption.paint(canvas, const Offset(36, 646));
  caption.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 690);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

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
        for (var index = 0; index < _titles.length; index++) {
          final bytes = await _cover(index);
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
        for (var index = 0; index < _titles.length; index++)
          CatalogueItem(
            kind: CatalogueKind.series,
            id: 'series-$index',
            title: _titles[index],
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
        for (var index = 0; index < _titles.length; index++)
          CatalogueItem(
            kind: CatalogueKind.book,
            id: 'book-$index',
            title: '${_titles[index]} · Volume ${index + 1}',
            libraryId: series[index].libraryId,
            seriesId: series[index].id,
            number: index + 1,
            pageCount: 192,
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
      Future<void> capture(String filename) async {
        await settleReaderImages(tester);
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('docs/screenshots/$filename.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.text('Continue reading'), findsOneWidget);
      await capture('phone-home');
      final router = harness.container.read(routerProvider);
      router.go('/libraries');
      await tester.pumpAndSettle();
      await capture('phone-library');
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      await capture('phone-appearance');
      router.go('/');
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      await capture('tablet-home');
      await harness.close(tester);
    },
    skip: Platform.environment['INKORA_CAPTURE_SCREENSHOTS'] != 'true',
  );
}
