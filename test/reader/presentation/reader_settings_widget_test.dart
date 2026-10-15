import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  testWidgets(
    'preferences distinguish profiles, clear old local tuning and inherit legacy layout',
    (tester) async {
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      ReaderSettingsSheet(store: store, manifest: manifest),
                ),
                child: const Text('Preferences'),
              ),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await settleReaderImages(tester);
      }

      Future<void> select(String field, String choice) async {
        final control = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == field,
        );
        await tester.ensureVisible(control);
        await tester.tap(control);
        await settleReaderImages(tester);
        await tester.tap(find.text(choice).last);
        await settleReaderImages(tester);
      }

      Future<void> save() async {
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settle();
      }

      try {
        await tester.tap(find.text('Preferences'));
        await settle();
        expect(find.text('Single page'), findsOneWidget);
        await tester.ensureVisible(find.text('Reset to default'));
        await tester.tap(find.text('Reset to default'));
        await settle();
        await save();
        final inherited = (await tester.runAsync(
          () => store.overrides(SettingsScope.book, manifest.bookId),
        ))!;
        expect(inherited.spreads, isNull);
        expect(inherited.layout, isNull);
        for (final (label, mode) in [
          ('Manga', ReadingMode.manga),
          ('Comics', ReadingMode.comics),
        ]) {
          await tester.tap(find.text('Preferences'));
          await settle();
          await select('Mode', label);
          await save();
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
          expect(
            settings.layout,
            mode == ReadingMode.manga
                ? ReadingLayout.doublePage
                : ReadingLayout.automatic,
          );
          expect(settings.spacing, 0);
          expect(settings.fit, ReadingFit.page);
        }
      } finally {
        await tester.runAsync(database.close);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'preferences UI clears book overrides and saves inherited global changes',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = ReaderStore(database, 'reader-account');
      final manifest = readerManifest();
      await tester.runAsync(
        () => store.saveOverrides(
          SettingsScope.book,
          manifest.bookId,
          const ReadingOverrides(mode: ReadingMode.webtoon, spacing: 2.5),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      ReaderSettingsSheet(store: store, manifest: manifest),
                ),
                child: const Text('Preferences'),
              ),
            ),
          ),
        ),
      );
      Future<void> settleStorage() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await settleReaderImages(tester);
      }

      try {
        await tester.tap(find.text('Preferences'));
        await settleStorage();
        expect(find.text('2.5 (custom)'), findsOneWidget);
        await tester.ensureVisible(find.text('Reset to default'));
        await tester.tap(find.text('Reset to default'));
        await tester.pump();
        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await settleStorage();
        final cleared = await tester.runAsync(
          () => store.overrides(SettingsScope.book, manifest.bookId),
        );
        expect(cleared!.mode, isNull);
        expect(cleared.spacing, isNull);
        await tester.tap(find.text('Preferences'));
        await settleStorage();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DropdownButtonFormField<SettingsScope>,
          ),
        );
        await settleReaderImages(tester);
        await tester.tap(find.text('Global').last);
        await settleStorage();
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String> &&
                w.decoration.labelText == 'Mode',
          ),
        );
        await settleReaderImages(tester);
        await tester.tap(find.text('Webtoon').last);
        await settleReaderImages(tester);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settleStorage();
        final settings = await tester.runAsync(
          () => store.settings(manifest).first,
        );
        expect(settings!.mode, ReadingMode.webtoon);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(database.close);
        await tester.pumpWidget(const SizedBox.shrink());
        await settleReaderImages(tester);
      }
    },
  );
}
