import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/ebook_fonts.dart';
import 'package:inkora/reader/presentation/reader_settings_scope_selector.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import 'reader_settings_sections_test.dart'
    show openSheet, settle, chooseBackground;

final _manifest = ReaderManifest(
  accountId: 'order',
  bookId: 'book',
  revision: 'r1',
  title: 'Fixture',
  libraryId: 'library',
  seriesId: 'series',
  documentType: 'application/epub+zip',
  pages: [PageDimensions(1, 1)],
);

Future<ReaderStore> mount(
  WidgetTester tester, {
  Size size = const Size(1024, 768),
  double scale = 1,
  Locale locale = const Locale('en'),
  ReadingOverrides? overrides,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final store = ReaderStore(db, _manifest.accountId);
  await tester.runAsync(() async {
    await store.saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(mode: ReadingMode.ebook),
    );
    if (overrides != null) {
      await store.saveOverrides(
        SettingsScope.book,
        _manifest.bookId,
        overrides,
      );
    }
  });
  await openSheet(tester, store, _manifest, locale: locale);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return store;
}

Future<void> tab(WidgetTester tester, String label) async {
  final heading = find.text(label).last;
  await tester.ensureVisible(heading);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SETTINGS_ORDER')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('preferences-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    const directory = String.fromEnvironment(
      'SETTINGS_CAPTURE_DIRECTORY',
      defaultValue: 'artifacts/reading-settings-density/screenshots',
    );
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void registerSettingsDensityTest() {
  testWidgets('sectioned navigation aligns switch edges without reset chrome', (
    tester,
  ) async {
    await mount(tester);
    await tab(tester, 'Navigation');
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
    // Every navigation action remains reachable in the shared scroll form.
    for (final label in ['Tap to turn pages', 'Page turn animation']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

void main() {
  registerSettingsDensityTest();
  for (final (locale, size, scale) in [
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(1024, 768),
      const Size(844, 390),
    ])
      for (final scale in [1.0, 2.0]) (const Locale('en'), size, scale),
    for (final locale in AppStrings.supportedLocales)
      (locale, const Size(320, 640), 2.0),
    (const Locale('fr'), const Size(1024, 768), 1.0),
    (const Locale('fr'), const Size(390, 844), 1.0),
  ]) {
    testWidgets('ordered EPUB sections and header scope at $locale/$size/$scale', (
      tester,
    ) async {
      if (const bool.fromEnvironment('CAPTURE_SETTINGS_ORDER')) {
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
            await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
          }
          final font = File(
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/devtools_app_shared/fonts/Roboto/Roboto-Regular.ttf',
          );
          await (FontLoader(
            'Roboto',
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        });
      }
      final store = await mount(
        tester,
        size: size,
        scale: scale,
        locale: locale,
      );
      final before = (await tester.runAsync(
        () => store.overrides(SettingsScope.book, 'book'),
      ))!.toJson();
      final scope = find.byKey(const Key('reader-settings-scope'));
      expect(scope.hitTestable(), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
      final strings = AppStrings(locale.languageCode);
      final labels = ['Appearance', 'Page layout', 'Navigation', 'Templates'];
      double? previous;
      for (final label in labels) {
        final heading = find.text(strings.text(label)).last;
        // Compare content positions, compensating for the form's scroll.
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(ReaderSettingsSheet),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        final top = tester.getTopLeft(heading).dy + position.pixels;
        if (previous != null) expect(top, greaterThan(previous));
        previous = top;
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        expect(heading.hitTestable(), findsOneWidget);
      }
      final original = tester.state(find.byType(ReaderSettingsSheet));
      tester.view.physicalSize = size.height > size.width
          ? const Size(1024, 768)
          : const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ReaderSettingsSheet)), same(original));
      expect(
        (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!.toJson(),
        before,
      );
      await capture(
        tester,
        '${locale.languageCode}-${size.width.toInt()}-${(scale * 100).round()}-sections',
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final initiallyEnabled in [true, false]) {
    testWidgets(
      'changing background preserves texture $initiallyEnabled and saved legacy paper',
      (tester) async {
        final store = await mount(
          tester,
          overrides: ReadingOverrides(
            background: ReadingBackground.paper,
            ebook: initiallyEnabled ? null : {'paperTexture': false},
          ),
        );
        final texture = find.byKey(const Key('ebook-paper-texture'));
        for (final color in ['black', 'sepia', 'white', 'gray', 'slate']) {
          await chooseBackground(tester, color);
          await settle(tester);
          final saved = (await tester.runAsync(
            () => store.overrides(SettingsScope.book, 'book'),
          ))!;
          expect(saved.background!.name, color);
          expect(saved.ebook!['paperTexture'], initiallyEnabled);
          expect(
            tester.widget<SwitchListTile>(texture).value,
            initiallyEnabled,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'section scrolling and live resize preserve the target without preference writes',
    (tester) async {
      final store = await mount(tester);
      var writes = 0;
      final updates = store.database
          .tableUpdates(
            TableUpdateQuery.onTable(store.database.readingPreferences),
          )
          .listen((_) => writes++);
      addTearDown(updates.cancel);
      final original = tester.state(find.byType(ReaderSettingsSheet));
      await tab(tester, 'Templates');
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(original));
        expect(
          tester
              .widget<ReaderSettingsScopeSelector>(
                find.byType(ReaderSettingsScopeSelector),
              )
              .scope,
          SettingsScope.book,
        );
        expect(find.byKey(const Key('ebook-style-fantasy')), findsOneWidget);
        await tester.tap(find.byKey(const Key('reader-settings-scope')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reader-choice-scope-book')));
        await settle(tester);
      }
      expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
