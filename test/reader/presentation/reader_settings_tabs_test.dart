import 'package:inkora/reader/presentation/ebook_font_picker.dart';

import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';
import 'package:inkora/reader/presentation/reader_settings_layout.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> openSheet(
  WidgetTester tester,
  ReaderStore store,
  ReaderManifest manifest, {
  Locale? locale,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('preferences-capture'),
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: InkoraTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ReaderSettingsSheet(
                  store: store,
                  manifest: manifest,
                  modal: true,
                ),
              ),
              child: const Text('Open preferences'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open preferences'));
  await settle(tester);
}

void main() {
  testWidgets('slider drag keeps parent work local and commits exactly once', (
    tester,
  ) async {
    var parentBuilds = 0;
    final commits = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            parentBuilds++;
            return Scaffold(
              body: InkSlider(
                label: 'Line spacing',
                formatValue: (v) => '$v',
                value: 1,
                min: .7,
                max: 2.5,
                divisions: 18,
                onCommitted: commits.add,
              ),
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(1 + i / 20);
      await tester.pump();
    }
    expect(commits, isEmpty);
    expect(parentBuilds, 1);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1.95);
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(1.95);
    await tester.pump();
    expect(commits, [1.95]);
    expect(parentBuilds, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'choice chips replace dropdowns and keep complete labels at 200 % text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ReaderStore(db, 'long-labels');
      final manifest = ReaderManifest(
        accountId: store.accountId,
        bookId: 'comics',
        revision: 'r1',
        title: 'Fixture',
        pages: [PageDimensions(768, 1152)],
      );
      await openSheet(tester, store, manifest);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final automatic = find.byKey(const Key('reader-choice-layout-automatic'));
      await tester.ensureVisible(automatic);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(automatic).selected, isTrue);
      expect(
        find.text('Two pages in landscape windows and on tablets.'),
        findsOneWidget,
      );
      for (final label in [
        'Left to right',
        'Right to left',
        'Vertical pages',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final kind in ['manga', 'comics', 'webtoon', 'epub', 'pdf']) {
    for (final size in [
      const Size(320, 640),
      const Size(1024, 768),
      const Size(844, 390),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$kind tabs show applicable controls and reachable actions at $size/$scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            final store = ReaderStore(db, 'tabs-account');
            final document = kind == 'epub' || kind == 'pdf';
            await tester.runAsync(
              () => store.saveOverrides(
                SettingsScope.global,
                '',
                ReadingOverrides(
                  mode: document
                      ? ReadingMode.ebook
                      : ReadingMode.values.byName(kind),
                ),
              ),
            );
            final manifest = ReaderManifest(
              accountId: store.accountId,
              bookId: 'test',
              revision: 'r1',
              title: 'Fixture',
              libraryId: 'library',
              seriesId: 'series',
              documentType: document
                  ? (kind == 'epub'
                        ? 'application/epub+zip'
                        : 'application/pdf')
                  : null,
              pages: [PageDimensions(768, 1152)],
            );
            await openSheet(tester, store, manifest);
            final tabs = find.byType(Tab);
            expect(
              tabs,
              kind == 'pdf'
                  ? findsNothing
                  : findsNWidgets(
                      kind == 'epub'
                          ? 4
                          : kind == 'webtoon'
                          ? 3
                          : 2,
                    ),
            );
            expect(
              find.text('Appearance'),
              kind == 'epub' ? findsOneWidget : findsNothing,
            );
            expect(
              find.text('Rendering'),
              document ? findsNothing : findsOneWidget,
            );
            expect(
              find.text('Preloading'),
              kind == 'webtoon' ? findsOneWidget : findsNothing,
            );
            expect(
              find.text('Direction'),
              document || kind == 'webtoon' ? findsNothing : findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('ebook-lineHeight')),
              kind == 'epub' ? findsOneWidget : findsNothing,
            );
            if (kind == 'pdf' && size.width == 1024 && scale == 1) {
              expect(
                find.byKey(const Key('reader-background-sepia')),
                findsOneWidget,
              );
              expect(
                find.byKey(const Key('reader-choice-fit-page')),
                findsOneWidget,
              );
              await tester.ensureVisible(find.text('Continuous scrolling'));
              await tester.pumpAndSettle();
              expect(
                find.text('Continuous scrolling').hitTestable(),
                findsOneWidget,
              );
            }

            if (kind == 'epub') {
              await tester.ensureVisible(find.text('Appearance'));
              await tester.tap(find.text('Appearance'));
              await tester.pumpAndSettle();
              expect(find.byType(EbookFontPicker), findsOneWidget);
              expect(find.text('Background'), findsOneWidget);
              expect(find.text('Publisher styles'), findsOneWidget);
            }
            if (const bool.fromEnvironment('CAPTURE_READER_SETTINGS')) {
              if ((kind == 'epub' || kind == 'manga') &&
                  size.width == 1024 &&
                  scale == 1) {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('preferences-capture')),
                );
                await tester.runAsync(() async {
                  final image = await boundary.toImage();
                  final bytes = await image.toByteData(
                    format: ImageByteFormat.png,
                  );
                  final file = File('artifacts/ebooks/settings-$kind.png');
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
            }
            expect(find.text('Save'), findsNothing);
            final reset = find.byKey(const Key('reader-settings-menu'));
            await tester.ensureVisible(reset);
            await tester.pumpAndSettle();
            expect(reset.hitTestable(), findsOneWidget);
            final scope = find.byKey(const Key('reader-settings-scope'));
            await tester.ensureVisible(scope);
            await tester.pumpAndSettle();
            expect(scope.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets(
    'raster books under global ebook defaults only expose raster controls',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ReaderStore(db, 'raster-defaults');
      await tester.runAsync(
        () => store.saveOverrides(
          SettingsScope.global,
          '',
          const ReadingOverrides(mode: ReadingMode.ebook),
        ),
      );
      final manifest = ReaderManifest(
        accountId: store.accountId,
        bookId: 'raster',
        revision: 'r1',
        title: 'Raster fixture',
        pages: [PageDimensions(768, 1152)],
      );
      await openSheet(tester, store, manifest);
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Rendering'), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Font'), findsNothing);
      expect(find.text('Page layout'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'EPUB tab changes apply immediately and stay visible across tabs',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ReaderStore(db, 'drafts');
      final manifest = ReaderManifest(
        accountId: 'drafts',
        bookId: 'epub',
        revision: 'r1',
        title: 'Fixture',
        documentType: 'application/epub+zip',
        pages: [PageDimensions(1, 1)],
      );
      await openSheet(tester, store, manifest);
      expect(
        // The native system inset belongs to SafeArea, outside the capped form.
        tester.getSize(find.byType(DefaultTabController)).height,
        lessThanOrEqualTo(560),
      );
      expect(
        find.byKey(const Key('reader-choice-ebook-text-columns-auto')),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Navigation'));
      await tester.tap(find.text('Navigation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tap to turn pages'));
      await tester.tap(find.text('Tap to turn pages'));
      await settle(tester);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(find.byKey(const ValueKey('ebook-lineHeight')))
          .onChangeEnd!(1.8);
      await settle(tester);
      // Applied without Save: the book scope already holds the value.
      expect(
        (await tester.runAsync(
          () => store.overrides(SettingsScope.book, 'epub'),
        ))!.ebook!['lineHeight'],
        1.8,
      );
      await tester.ensureVisible(find.text('Page layout'));
      await tester.tap(find.text('Page layout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('reader-background-black')),
      );
      await tester.tap(find.byKey(const Key('reader-background-black')));
      await settle(tester);
      await tester.ensureVisible(find.text('Page layout'));
      await tester.tap(find.text('Page layout'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Center page divider'));
      await tester.tap(find.text('Center page divider'));
      await settle(tester);
      await tester.ensureVisible(find.text('Navigation'));
      await tester.tap(find.text('Navigation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Page turn animation'));
      await tester.tap(find.text('Page turn animation'));
      await settle(tester);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('ebook-lineHeight')))
            .value,
        1.8,
      );
      final saved = await tester.runAsync(
        () => store.overrides(SettingsScope.book, 'epub'),
      );
      expect(saved!.ebook!['lineHeight'], 1.8);
      expect(saved.ebook!['tapToTurnPages'], isTrue);
      expect(saved.ebook!['columnSeparator'], isTrue);
      expect(saved.pageAnimation, isFalse);
      expect(saved.background, ReadingBackground.black);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
