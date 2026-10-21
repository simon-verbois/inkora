import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

import 'reader_settings_tabs_test.dart' show openSheet, settle;

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'manual ebook styles keep scoped font size and apply immediately at $size / $scale',
        (tester) async {
          if (const bool.fromEnvironment('CAPTURE_READER_SETTINGS')) {
            await tester.runAsync(() async {
              for (final (family, asset) in [
                ('LibreBaskerville', 'assets/fonts/LibreBaskerville.ttf'),
                ('PhosphorRegular', 'assets/icons/Phosphor-Regular.ttf'),
                ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
              ]) {
                await (FontLoader(
                  family,
                )..addFont(rootBundle.load(asset))).load();
              }
              final sdk = Platform.environment['FLUTTER_ROOT']!;
              final font = File(
                '$sdk/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf',
              );
              await (FontLoader(
                'Roboto',
              )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
            });
          }
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          final store = ReaderStore(database, 'account');
          final manifest = ReaderManifest(
            accountId: 'account',
            bookId: 'epub',
            revision: 'r1',
            title: 'Fixture',
            documentType: 'application/epub+zip',
            pages: [PageDimensions(1, 1)],
          );
          await tester.runAsync(
            () => store.saveOverrides(
              SettingsScope.global,
              '',
              const ReadingOverrides(
                mode: ReadingMode.ebook,
                background: ReadingBackground.white,
                ebook: {'fontSize': 1.8, 'scroll': true, 'columns': 'one'},
              ),
            ),
          );
          await openSheet(tester, store, manifest);
          // An existing explicit background must not be replaced on opening.
          expect(
            find.byKey(const Key('reader-background-white')),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Reading style'));
          await tester.tap(find.text('Reading style'));
          await tester.pumpAndSettle();
          final science = find.byKey(
            const ValueKey('ebook-style-scienceFiction'),
          );
          await tester.ensureVisible(science);
          await tester.tap(science);
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('CAPTURE_READER_SETTINGS') &&
              scale == 1) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('preferences-capture')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(format: ImageByteFormat.png);
              final file = File(
                'artifacts/ebook-bookmark-styles/style-${size.width.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          // The style applies at once; the other tabs show its values.
          await settle(tester);
          await tester.ensureVisible(find.text('Typography'));
          await tester.tap(find.text('Typography'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Slider>(find.byKey(const ValueKey('ebook-fontSize')))
                .value,
            1.8,
          );
          expect(find.text('Save'), findsNothing);
          final saved = (await tester.runAsync(
            () => store.settings(manifest).first,
          ))!;
          expect(EbookStyle.scienceFiction.matches(saved), true);
          expect(saved.ebook.fontSize, 1.8);
          expect(saved.ebook.scroll, true);
          expect(saved.ebook.columns, 'one');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await openSheet(tester, store, manifest);
          await tester.ensureVisible(find.text('Reading style'));
          await tester.tap(find.text('Reading style'));
          await tester.pumpAndSettle();
          final fantasy = find.byKey(const ValueKey('ebook-style-fantasy'));
          await tester.ensureVisible(fantasy);
          await tester.tap(fantasy);
          await settle(tester);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Reading style'), findsNothing);
          expect(
            EbookStyle.fantasy.matches(
              (await tester.runAsync(() => store.settings(manifest).first))!,
            ),
            true,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
