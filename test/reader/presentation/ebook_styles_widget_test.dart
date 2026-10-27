import 'package:inkora/reader/presentation/ebook_font_picker.dart';

import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/ebook_fonts.dart';

import 'reader_settings_tabs_test.dart' show openSheet, settle;

void main() {
  for (final (locale, size, scale) in [
    for (final locale in AppStrings.supportedLocales)
      (locale, const Size(320, 640), 2.0),
    (const Locale('fr'), const Size(320, 640), 1.0),
    (const Locale('fr'), const Size(1024, 768), 1.0),
    (const Locale('fr'), const Size(1024, 768), 2.0),
  ]) {
    testWidgets(
      'localized templates update font dropdown at $locale/$size/$scale',
      (tester) async {
        const captureEnabled = bool.fromEnvironment('CAPTURE_EPUB_TYPOGRAPHY');
        if (captureEnabled) {
          await tester.runAsync(() async {
            for (final (family, asset) in [
              ('LibreBaskerville', 'assets/fonts/LibreBaskerville.ttf'),
              ('PhosphorRegular', 'assets/icons/Phosphor-Regular.ttf'),
              ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
              for (final font in EbookFont.values)
                if (font.previewFamily != null && font != EbookFont.baskerville)
                  (
                    font.previewFamily!,
                    'assets/fonts/${font.previewFamily}-Regular.ttf',
                  ),
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
        Future<void> capture(String state) async {
          if (!captureEnabled) return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('preferences-capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ImageByteFormat.png);
            final file = File(
              'artifacts/epub-refinement/screenshots/$locale-${size.width.toInt()}-${(scale * 100).round()}-$state.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final store = ReaderStore(db, 'templates');
        final manifest = ReaderManifest(
          accountId: store.accountId,
          bookId: 'epub',
          revision: 'r1',
          title: 'Fixture',
          documentType: 'application/epub+zip',
          pages: [PageDimensions(1, 1)],
        );
        final strings = AppStrings(locale.languageCode);
        await openSheet(tester, store, manifest, locale: locale);
        final templates = find.text(strings.text('Templates'));
        await tester.ensureVisible(templates);
        await tester.tap(templates);
        await tester.pumpAndSettle();
        final description = find.text(
          strings.text('Choose a template. You can adjust it afterwards.'),
        );
        expect(description, findsOneWidget);
        final samples = find.text('Aa');
        expect(samples, findsNWidgets(6));
        for (var i = 0; i < 6; i++) {
          expect(
            tester.getSize(samples.at(i)).height,
            lessThanOrEqualTo(36 * scale + 1),
          );
        }
        await capture('templates');
        final fantasy = find.byKey(const ValueKey('ebook-style-fantasy'));
        await tester.ensureVisible(fantasy);
        await tester.tap(fantasy);
        await settle(tester);
        final typography = find.text(strings.text('Appearance'));
        await tester.ensureVisible(typography);
        await tester.tap(typography);
        await tester.pumpAndSettle();
        final dropdown = find.byType(EbookFontPicker);
        await tester.ensureVisible(dropdown);
        await capture('typography');
        expect(
          tester.widget<EbookFontPicker>(dropdown).font,
          EbookFont.gentium,
        );
        expect(find.byKey(const ValueKey('ebook-fontSize')), findsNothing);
        expect(
          (await tester.runAsync(() => store.settings(manifest).first))!
              .ebook
              .fontSize,
          1.0,
        );
        if (captureEnabled) {
          await tester.tap(find.byKey(const Key('ebook-font-picker')));
          await tester.pumpAndSettle();
          await capture('fonts');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'ebook templates normalize legacy text zoom and apply immediately at $size / $scale',
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
            find.byKey(const Key('ebook-background-picker')),
            findsOneWidget,
          );
          expect(find.text('White'), findsOneWidget);
          await tester.ensureVisible(find.text('Templates'));
          await tester.tap(find.text('Templates'));
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
          await tester.ensureVisible(find.text('Appearance'));
          await tester.tap(find.text('Appearance'));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('ebook-fontSize')), findsNothing);
          expect(find.byType(EbookFontPicker), findsOneWidget);
          expect(find.text('Save'), findsNothing);
          final saved = (await tester.runAsync(
            () => store.settings(manifest).first,
          ))!;
          expect(EbookStyle.scienceFiction.matches(saved), true);
          expect(saved.ebook.fontSize, 1.0);
          expect(saved.ebook.scroll, true);
          expect(saved.ebook.columns, 'one');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await openSheet(tester, store, manifest);
          await tester.ensureVisible(find.text('Templates'));
          await tester.tap(find.text('Templates'));
          await tester.pumpAndSettle();
          final fantasy = find.byKey(const ValueKey('ebook-style-fantasy'));
          await tester.ensureVisible(fantasy);
          await tester.tap(fantasy);
          await settle(tester);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Templates'), findsNothing);
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
