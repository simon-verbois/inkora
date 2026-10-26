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
import 'package:inkora/reader/presentation/ebook_font_picker.dart';
import 'package:inkora/reader/presentation/ebook_fonts.dart';
import 'package:inkora/reader/presentation/reader_settings_scope_selector.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import 'reader_settings_tabs_test.dart' show openSheet, settle;

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

Future<void> tab(WidgetTester tester, String name) async {
  final finder = find.descendant(
    of: find.byType(TabBar),
    matching: find.text(name),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
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
  testWidgets('tablet navigation fits content and aligns header and switches', (
    tester,
  ) async {
    await mount(tester);
    await tab(tester, 'Navigation');
    final tapText = find.text('Tap to turn pages');
    final animationText = find.text('Page turn animation');
    Finder tile(Finder title) => find
        .ancestor(
          of: title,
          matching: find.byWidgetPredicate(
            (widget) => widget is SwitchListTile,
          ),
        )
        .first;
    Finder toggle(Finder title) =>
        find.descendant(of: tile(title), matching: find.byType(Switch));
    expect(tester.getRect(tapText).left, tester.getRect(animationText).left);
    expect(
      tester.getRect(toggle(tapText)).right,
      tester.getRect(toggle(animationText)).right,
    );
    expect(
      tester.getRect(tapText).center.dy,
      closeTo(tester.getRect(toggle(tapText)).center.dy, 1),
    );
    final trailing = tester.getRect(toggle(animationText)).right;
    final leading = tester.getRect(animationText).left;
    final panel = tester.getRect(find.byType(DefaultTabController));
    expect(panel.height, lessThan(460));
    expect(
      panel.bottom - tester.getRect(tile(animationText)).bottom,
      inInclusiveRange(0, 20),
    );
    final target = tester.getRect(
      find.byKey(const Key('reader-settings-scope')),
    );
    final more = tester.getRect(find.byKey(const Key('reader-settings-menu')));
    expect(target.right, lessThanOrEqualTo(more.left));
    expect(target.center.dy, more.center.dy);
    expect(find.text('Automatic saving'), findsNothing);
    expect(find.byKey(const Key('reader-settings-footer')), findsNothing);
    final oldHeight = panel.height;
    await tester.tap(
      find.byKey(const Key('reader-choice-ebook-reading-mode-scroll')),
    );
    await settle(tester);
    expect(
      tester.getSize(find.byType(DefaultTabController)).height,
      lessThan(oldHeight),
    );
    await tester.tap(
      find.byKey(const Key('reader-choice-ebook-reading-mode-pages')),
    );
    await settle(tester);
    await tab(tester, 'Page layout');
    final dividerText = find.text('Center page divider');
    expect(tester.getRect(dividerText).left, leading);
    expect(tester.getRect(toggle(dividerText)).right, trailing);
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
  ]) {
    testWidgets('ordered EPUB tabs and header scope at $locale/$size/$scale', (
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
      final strings = AppStrings(locale.languageCode);
      final scope = find.byKey(const Key('reader-settings-scope'));
      expect(tester.getRect(scope).height, greaterThanOrEqualTo(48));
      expect(scope.hitTestable(), findsOneWidget);
      expect(find.text('Apply to'), findsNothing);
      for (final color in [
        'white',
        'paper',
        'sepia',
        'gray',
        'slate',
        'black',
      ]) {
        expect(find.byKey(Key('reader-background-$color')), findsOneWidget);
      }
      for (final old in ['ivory', 'sage', 'mist']) {
        expect(find.byKey(Key('reader-background-$old')), findsNothing);
      }
      expect(find.byType(EbookFontPicker), findsOneWidget);
      expect(find.byKey(const Key('ebook-margin-picker')), findsNothing);
      expect(find.text(strings.text('Page turn animation')), findsNothing);
      expect(find.byKey(const Key('reader-settings-reset')), findsNothing);
      final stem =
          '${locale.languageCode}-${size.width.toInt()}-${(scale * 100).round()}';
      await capture(tester, '$stem-appearance');
      for (final name in [
        'Page layout',
        'Navigation',
        'Templates',
        'Appearance',
      ]) {
        await tab(tester, strings.text(name));
        await tester.ensureVisible(scope);
        await tester.pumpAndSettle();
        expect(scope.hitTestable(), findsOneWidget);
        if (name != 'Appearance') {
          await capture(tester, '$stem-${name.replaceAll(' ', '-')}');
        }
        if (name == 'Page layout') {
          expect(find.byKey(const Key('ebook-margin-picker')), findsOneWidget);
          expect(find.byType(EbookFontPicker), findsNothing);
          expect(find.text(strings.text('Background')), findsNothing);
          expect(find.text(strings.text('Page turn animation')), findsNothing);
        }
        if (name == 'Navigation') {
          final continuous = find.byKey(
            const Key('reader-choice-ebook-reading-mode-scroll'),
          );
          await tester.ensureVisible(continuous);
          await tester.tap(continuous);
          await settle(tester);
          expect(find.text(strings.text('Tap to turn pages')), findsNothing);
          expect(find.text(strings.text('Page turn animation')), findsNothing);
          final book = (await tester.runAsync(
            () => store.overrides(SettingsScope.book, 'book'),
          ))!;
          expect(book.ebook!['scroll'], true);
          final pages = find.byKey(
            const Key('reader-choice-ebook-reading-mode-pages'),
          );
          await tester.ensureVisible(pages);
          await tester.tap(pages);
          await settle(tester);
          expect(find.text(strings.text('Tap to turn pages')), findsOneWidget);
          expect(
            find.text(strings.text('Page turn animation')),
            findsOneWidget,
          );
        }
      }
      await tester.ensureVisible(scope);
      await tester.tap(scope);
      await tester.pumpAndSettle();
      for (final name in ['book', 'series', 'library', 'global']) {
        expect(
          find.byKey(Key('reader-choice-scope-$name')).hitTestable(),
          findsOneWidget,
        );
      }
      await capture(tester, '$stem-scope');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReaderSettingsScopeSelector>(
              find.byType(ReaderSettingsScopeSelector),
            )
            .scope,
        SettingsScope.book,
      );
      // Switching targets preserves the previously applied book changes.
      await tester.ensureVisible(scope);
      await tester.tap(scope);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader-choice-scope-global')));
      await settle(tester);
      expect(
        tester
            .widget<ReaderSettingsScopeSelector>(
              find.byType(ReaderSettingsScopeSelector),
            )
            .scope,
        SettingsScope.global,
      );
      expect(
        (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!.ebook!['scroll'],
        false,
      );
      expect(
        (await tester.runAsync(
          () => store.overrides(SettingsScope.global, ''),
        ))!.ebook,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final name in ['Appearance', 'Page layout', 'Navigation', 'Templates']) {
    testWidgets(
      'reset $name removes only its settings from the selected scope',
      (tester) async {
        final store = await mount(
          tester,
          overrides: const ReadingOverrides(
            mode: ReadingMode.ebook,
            background: ReadingBackground.black,
            pageAnimation: false,
            libraryDefaults: true,
            spacing: 9,
            ebook: {
              'font': 'lato',
              'fontSize': 1.8,
              'lineHeight': 1.8,
              'justify': true,
              'publisherStyles': true,
              'margins': 1.7,
              'pageInsets': {'left': 9, 'top': 10, 'right': 11, 'bottom': 12},
              'columns': 'two',
              'columnSeparator': true,
              'scroll': true,
              'tapToTurnPages': true,
            },
          ),
        );
        await tab(tester, name);
        Future<void> reset() async {
          final menu = find.byKey(const Key('reader-settings-menu'));
          await tester.ensureVisible(menu);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('reader-settings-reset')));
          await tester.pumpAndSettle();
        }

        await reset();
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, 'book'),
          ))!.ebook!['scroll'],
          true,
        );
        await reset();
        await tester.tap(find.text('Reset to default').last);
        await settle(tester);
        final saved = (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'book'),
        ))!;
        expect(saved.mode, ReadingMode.ebook);
        expect(saved.libraryDefaults, true);
        expect(saved.spacing, 9);
        expect(
          saved.background,
          name == 'Appearance' || name == 'Templates'
              ? isNull
              : ReadingBackground.black,
        );
        expect(saved.pageAnimation, name == 'Navigation' ? isNull : false);
        expect(
          saved.ebook!.containsKey('font'),
          name != 'Appearance' && name != 'Templates',
        );
        expect(
          saved.ebook!.containsKey('lineHeight'),
          name != 'Appearance' && name != 'Templates',
        );
        expect(
          saved.ebook!.containsKey('margins'),
          name != 'Page layout' && name != 'Templates',
        );
        expect(saved.ebook!.containsKey('columns'), name != 'Page layout');
        expect(saved.ebook!.containsKey('pageInsets'), name != 'Page layout');
        expect(
          saved.ebook!.containsKey('columnSeparator'),
          name != 'Page layout',
        );
        expect(saved.ebook!.containsKey('scroll'), name != 'Navigation');
        expect(
          saved.ebook!.containsKey('tapToTurnPages'),
          name != 'Navigation',
        );
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.global, ''),
          ))!.toJson(),
          const ReadingOverrides(mode: ReadingMode.ebook).toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'tab menus and live resize preserve the target without preference writes',
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
      final menu = find.byKey(const Key('reader-settings-menu'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reader-settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
