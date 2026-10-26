import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

Future<Object?> _backEvent(WidgetTester tester, String method) async {
  final channel = SystemChannels.backGesture;
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [0.0, 300.0],
            'progress': method == 'updateBackGestureProgress' ? .4 : 0.0,
            'swipeEdge': 0,
          }),
        ),
        null,
      );
  return response == null ? null : channel.codec.decodeEnvelope(response);
}

void main() {
  testWidgets(
    'reader preferences apply live without Save or Cancel, skip unchanged writes and survive predictive back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = AppDatabase(NativeDatabase.memory());
      final store = ReaderStore(database, 'reader-account');
      final manifest = readerManifest();
      // Open (migrate) the database outside the fake clock first.
      await tester.runAsync(
        () => store.overrides(SettingsScope.book, manifest.bookId),
      );
      var writes = 0;
      final updates = database
          .tableUpdates(
            TableUpdateQuery.onAllTables([database.readingPreferences]),
          )
          .listen((_) => writes++);
      late BuildContext root;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uiPreferencesProvider.overrideWith(
              (ref) => Stream.value(const UiPreferences()),
            ),
          ],
          child: MaterialApp(
            theme: InkoraTheme.forest(),
            home: Builder(
              builder: (context) {
                root = context;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await settleReaderImages(tester);
      }

      Future<void> open() async {
        showInkSheet<void>(
          context: root,
          child: ReaderSettingsSheet(
            modal: true,
            store: store,
            manifest: manifest,
          ),
        );
        await settle();
      }

      Future<void> choose(String key) async {
        if (key.startsWith('reader-choice-scope-')) {
          await tester.tap(find.byKey(const Key('reader-settings-scope')));
          await tester.pumpAndSettle();
        }
        final chip = find.byKey(Key(key));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await settle();
      }

      Future<ReadingOverrides> book() async => (await tester.runAsync(
        () => store.overrides(SettingsScope.book, manifest.bookId),
      ))!;

      try {
        await open();
        expect(find.byType(ReaderSettingsSheet), findsOneWidget);
        expect(find.text('Save'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Automatic saving'), findsNothing);
        // The editing target stays visible in the compact footer menu.
        expect(find.byKey(const Key('reader-settings-scope')), findsOne);
        expect(find.text('Apply to'), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);

        await choose('reader-choice-mode-manga');
        var saved = await book();
        expect(saved.mode, ReadingMode.manga);
        await choose('reader-choice-layout-doublePage');
        await choose('reader-background-sepia');
        saved = await book();
        expect(saved.layout, ReadingLayout.doublePage);
        expect(saved.background, ReadingBackground.sepia);
        final settings = (await tester.runAsync(
          () => store.settings(manifest).first,
        ))!;
        expect(settings.mode, ReadingMode.manga);
        expect(settings.direction, ReadingDirection.rightToLeft);
        expect(settings.layout, ReadingLayout.doublePage);

        // Tapping the selected choice again writes nothing.
        final before = writes;
        await choose('reader-choice-layout-doublePage');
        expect(writes, before);

        // Predictive back: a cancelled gesture keeps the sheet; a committed
        // one closes it with every change already applied. When the
        // framework declines the gesture, Android delivers a system back.
        if (await _backEvent(tester, 'startBackGesture') == true) {
          await _backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await _backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(find.byType(ReaderSettingsSheet), findsOneWidget);
          await _backEvent(tester, 'startBackGesture');
          await _backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await _backEvent(tester, 'commitBackGesture');
        } else {
          expect(find.byType(ReaderSettingsSheet), findsOneWidget);
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(ReaderSettingsSheet), findsNothing);
        expect((await book()).layout, ReadingLayout.doublePage);

        // Another scope loads its own layer and leaves the book untouched.
        await open();
        await choose('reader-choice-scope-global');
        await choose('reader-choice-mode-webtoon');
        final global = (await tester.runAsync(
          () => store.overrides(SettingsScope.global, ''),
        ))!;
        expect(global.mode, ReadingMode.webtoon);
        expect((await book()).mode, ReadingMode.manga);

        // Reset is confirmed first; cancelling keeps the values.
        await choose('reader-choice-scope-book');
        await tester.tap(find.byKey(const Key('reader-settings-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reader-settings-reset')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await settle();
        expect((await book()).mode, ReadingMode.manga);
        await tester.tap(find.byKey(const Key('reader-settings-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reader-settings-reset')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset to default').last);
        await settle();
        final cleared = await book();
        expect(cleared.mode, isNull);
        expect(cleared.layout, isNull);
        expect(cleared.background, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await updates.cancel();
          await database.close();
        });
      }
    },
  );

  testWidgets('profile changes clear local tuning of the selected scope', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = ReaderStore(database, 'reader-account');
    final manifest = readerManifest();
    await tester.runAsync(
      () => store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        const ReadingOverrides(
          mode: ReadingMode.paged,
          spreads: false,
          spacing: 24,
          direction: ReadingDirection.leftToRight,
          fit: ReadingFit.width,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderSettingsSheet(store: store, manifest: manifest),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await settleReaderImages(tester);
    }

    try {
      await settle();
      // The legacy explicit single-page choice is selected.
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('reader-choice-layout-single')),
            )
            .selected,
        isTrue,
      );
      for (final (key, mode) in [
        ('reader-choice-mode-manga', ReadingMode.manga),
        ('reader-choice-mode-comics', ReadingMode.comics),
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await settle();
        final settings = (await tester.runAsync(
          () => store.settings(manifest).first,
        ))!;
        expect(settings.mode, mode);
        expect(
          settings.direction,
          mode == ReadingMode.manga
              ? ReadingDirection.rightToLeft
              : ReadingDirection.leftToRight,
        );
        expect(settings.layout, ReadingLayout.automatic);
        expect(settings.spacing, 0);
        expect(settings.fit, ReadingFit.page);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(database.close);
    }
  });
}
