import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/presentation/reader_settings_layout.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/domain/content_key.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_content_bounds.dart';
import 'package:inkora/reader/presentation/reader_page_image.dart';
import 'package:inkora/reader/presentation/reader_viewport.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

class _PaperSource implements PageSource {
  _PaperSource(this.bytes);
  final Uint8List bytes;
  final requests = <ContentKey>[];
  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) async {
    requests.add(key);
    return EncodedPage(key: key, bytes: bytes, mediaType: 'image/png');
  }
}

Future<Uint8List> _page() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  canvas.drawRect(
    const Rect.fromLTWH(45, 65, 270, 470),
    Paint()..color = const Color(0xff2222aa),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 600);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  for (final language in languageNames.keys) {
    testWidgets(
      '$language content-fit choice remains usable at 200% phone text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? chosen;
        await tester.pumpWidget(
          MaterialApp(
            locale: AppStrings.localeFor(language),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ReaderChoiceGroup(
                      id: 'fit',
                      label: 'Fit',
                      choices: const {
                        'page': 'Fit page',
                        'width': 'Fit width',
                        'content': 'Fit content',
                      },
                      selected: 'page',
                      onSelected: (value) => chosen = value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final choice = find.byKey(const Key('reader-choice-fit-content'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings(language).text('Fit content')),
          findsOneWidget,
        );
        final rect = tester.getRect(choice);
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(304));
        expect(rect.height, greaterThanOrEqualTo(48));
        await tester.tap(choice);
        expect(chosen, 'content');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'content fit enlarges artwork with no extra acquisition at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ReaderContentBounds.cache.pause(false);
        ReaderContentBounds.cache.clear();
        addTearDown(ReaderContentBounds.cache.clear);
        final source = _PaperSource((await tester.runAsync(_page))!);
        final manifest = readerManifest(
          book: 'content-fit-${size.width}',
          dimensions: [PageDimensions(360, 600), PageDimensions(360, 600)],
        );
        final reader = OpenReader(manifest, source, ReaderLocator(0));
        final positions = <ReaderLocator>[];
        const capture = Key('content-capture');
        Future<void> mount(ReadingFit fit) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: RepaintBoundary(
                  key: capture,
                  child: ReaderViewport(
                    reader: reader,
                    settings: ReadingSettings(
                      mode: ReadingMode.manga,
                      spreadOffset: false,
                      fit: fit,
                      background: ReadingBackground.white,
                    ),
                    controlsVisible: false,
                    saveLocator: (locator) async => positions.add(locator),
                  ),
                ),
              ),
            ),
          );
          await settleReaderImages(tester);
        }

        Future<int> artworkPixels(String name) async {
          return (await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                .toImage();
            try {
              if (Platform.environment['INKORA_CONTENT_FIT_CAPTURES'] == '1') {
                final png = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final path = Directory('artifacts/content-fit')
                  ..createSync(recursive: true);
                File('${path.path}/${size.width.toInt()}-$name.png')
                    .writeAsBytesSync(png!.buffer.asUint8List());
              }
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              var count = 0;
              for (var i = 0; i < bytes.length; i += 4) {
                if (bytes[i] < 100 &&
                    bytes[i + 1] < 100 &&
                    bytes[i + 2] > 120) {
                  count++;
                }
              }
              return count;
            } finally {
              image.dispose();
            }
          }))!;
        }

        await mount(ReadingFit.page);
        final state = tester.state(find.byType(ReaderViewport));
        final original = await artworkPixels('original');
        final acquisitions = source.requests.length;
        expect(ReaderContentBounds.cache.length, 0);
        await mount(ReadingFit.content);
        for (var attempt = 0; attempt < 40; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (ReaderContentBounds.cache.peek(manifest.key(0)) != null &&
              ReaderContentBounds.cache.peek(manifest.key(1)) != null) {
            break;
          }
        }
        await settleReaderImages(tester);
        expect(ReaderContentBounds.cache.peek(manifest.key(0))?.cropped, true);
        final enlarged = await artworkPixels('content');
        expect(
          tester
              .widgetList<ReaderPageImage>(find.byType(ReaderPageImage))
              .first
              .contentBounds
              .cropped,
          true,
        );
        expect(enlarged, greaterThan(original * 1.25));
        expect(source.requests.length, acquisitions);
        expect(tester.state(find.byType(ReaderViewport)), same(state));
        expect(positions, isEmpty);
        await mount(ReadingFit.page);
        expect(await artworkPixels('restored'), original);
        expect(source.requests.length, acquisitions);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test(
    'content fit preserves scoped JSON with explicit parent and book choices',
    () {
      final parent = ReadingOverrides.fromJson(
        const ReadingOverrides(fit: ReadingFit.content).toJson(),
      );
      expect(ReadingSettings.resolve([parent]).fit, ReadingFit.content);
      expect(
        ReadingSettings.resolve([
          parent,
          const ReadingOverrides(fit: ReadingFit.page),
        ]).fit,
        ReadingFit.page,
      );
      expect(
        ReadingSettings.resolve([
          parent,
          const ReadingOverrides(mode: ReadingMode.webtoon),
        ]).fit,
        ReadingFit.comfort,
      );
    },
  );
}
