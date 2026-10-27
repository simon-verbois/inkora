import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/ebook_colors_dialog.dart';

import 'reader_settings_order_test.dart' show mount, capture;
import 'reader_settings_tabs_test.dart' show settle, chooseBackground;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (locale, size, scale) in [
    for (final locale in AppStrings.supportedLocales)
      (locale, const Size(320, 640), 2.0),
    (const Locale('en'), const Size(1024, 768), 1.0),
    (const Locale('fr'), const Size(844, 390), 2.0),
  ]) {
    testWidgets(
      'custom popup previews, cancels and saves colors at $locale/$size/$scale',
      (tester) async {
        if (const bool.fromEnvironment('CAPTURE_SETTINGS_ORDER')) {
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
            final roboto = File(
              '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf',
            );
            await (FontLoader(
              'Roboto',
            )..addFont(roboto.readAsBytes().then(ByteData.sublistView))).load();
          });
        }
        final store = await mount(
          tester,
          size: size,
          scale: scale,
          locale: locale,
          overrides: const ReadingOverrides(ebook: {'paperTexture': true}),
        );
        final strings = AppStrings(locale.languageCode);
        final stem =
            '${locale.languageCode}-${size.width.toInt()}-${(scale * 100).round()}';
        await capture(tester, '$stem-custom-button');
        await chooseBackground(tester, 'custom');
        expect(find.byType(EbookColorsDialog), findsOneWidget);
        final background = find.byKey(const Key('ebook-background-hex'));
        await tester.ensureVisible(background);
        await tester.enterText(background, '102030');
        await tester.pumpAndSettle();
        final preview = find.byKey(const Key('ebook-color-preview'));
        expect(
          (tester.widget<Container>(preview).decoration! as BoxDecoration)
              .color,
          const Color(0xff102030),
        );
        expect(
          tester.widget<Text>(find.text('Aa Bb Cc · 0123')).style!.color,
          Colors.white,
        );
        if (const bool.fromEnvironment('CAPTURE_SETTINGS_ORDER')) {
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          await capture(tester, '$stem-custom-automatic');
        }

        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, 'book'),
          ))!.ebook!.containsKey('customColors'),
          false,
        );
        await tapVisible(tester, find.text(strings.text('Cancel')));
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, 'book'),
          ))!.ebook!.containsKey('customColors'),
          false,
        );
        await chooseBackground(tester, 'custom');
        await tester.ensureVisible(background);
        await tester.enterText(background, 'F0E0D0');
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Aa Bb Cc · 0123')).style!.color,
          Colors.black,
        );
        await tapVisible(tester, find.byKey(const Key('ebook-automatic-text')));
        final text = find.byKey(const Key('ebook-text-hex'));
        await tester.ensureVisible(text);
        await tester.enterText(text, '123456');
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Aa Bb Cc · 0123')).style!.color,
          const Color(0xff123456),
        );
        if (const bool.fromEnvironment('CAPTURE_SETTINGS_ORDER')) {
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          await capture(tester, '$stem-custom-manual');
        }
        await tapVisible(tester, find.byKey(const Key('ebook-colors-save')));
        await settle(tester);
        final saved = (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!;
        expect(saved.ebook!['customColors'], true);
        expect(saved.ebook!['backgroundColor'], 0xf0e0d0);
        expect(saved.ebook!['textColor'], 0x123456);
        expect(saved.ebook!['paperTexture'], true);
        // A normal swatch leaves the remembered custom pair available to edit.
        await chooseBackground(tester, 'black');
        await settle(tester);
        final standard = (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!;
        expect(standard.ebook!['customColors'], false);
        expect(standard.ebook!['backgroundColor'], 0xf0e0d0);
        await chooseBackground(tester, 'custom');
        expect(tester.widget<TextField>(background).controller!.text, 'F0E0D0');
        expect(tester.widget<TextField>(text).controller!.text, '123456');
        await tapVisible(tester, find.text(strings.text('Cancel')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'hex validation, sliders, keyboard and Back retain a local draft',
    (tester) async {
      final store = await mount(tester);
      await chooseBackground(tester, 'custom');
      final field = find.byKey(const Key('ebook-background-hex'));
      await tester.enterText(field, '12');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('ebook-colors-save')))
            .onPressed,
        isNull,
      );
      expect(find.text('Enter six hexadecimal digits.'), findsOneWidget);
      await tester.enterText(field, '008800');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('ebook-background-hue')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('ebook-colors-save')))
            .onPressed,
        isNotNull,
      );
      // Switching to automatic must ignore a discarded, invalid manual field.
      await tapVisible(tester, find.byKey(const Key('ebook-automatic-text')));
      await tester.enterText(find.byKey(const Key('ebook-text-hex')), '1');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('ebook-automatic-text')));
      await tapVisible(tester, find.byKey(const Key('ebook-automatic-text')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('ebook-colors-save')))
            .onPressed,
        isNotNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EbookColorsDialog), findsNothing);
      expect(
        (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!.ebook,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
