import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

void main() {
  for (final qualityOnly in [true, false]) {
    testWidgets(
      '${qualityOnly ? 'quality' : 'reading'} reset preserves the other section and account',
      (tester) async {
        final database = AppDatabase(NativeDatabase.memory());
        final store = ReaderStore(database, 'quality-account');
        final other = ReaderStore(database, 'other-account');
        const initial = ReadingOverrides(
          mode: ReadingMode.manga,
          spacing: 24,
          webtoonQuality: WebtoonQuality.saver,
          imageQuality: {
            RasterFormat.png: RasterQuality(filter: VisualFilter.grayscale),
          },
        );
        await tester.runAsync(() async {
          await store.saveOverrides(SettingsScope.global, '', initial);
          await other.saveOverrides(SettingsScope.global, '', initial);
        });
        var saves = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderSettingsSheet(
                store: store,
                qualityOnly: qualityOnly,
                onSaved: () => saves++,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Reset to default'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset to default'));
        await tester.pumpAndSettle();
        // Confirmed reset applies at once; there is no Save step.
        expect(find.text('Save'), findsNothing);
        await tester.tap(find.text('Reset to default').last);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final saved = (await tester.runAsync(
          () => store.overrides(SettingsScope.global, ''),
        ))!;
        expect(saves, 0);
        if (qualityOnly) {
          expect(saved.mode, ReadingMode.manga);
          expect(saved.spacing, 24);
          expect(saved.imageQuality, isNull);
          expect(saved.webtoonQuality, WebtoonQuality.saver);
        } else {
          expect(saved.mode, isNull);
          expect(saved.spacing, isNull);
          expect(
            saved.imageQuality![RasterFormat.png]!.filter,
            VisualFilter.grayscale,
          );
          expect(saved.webtoonQuality, WebtoonQuality.saver);
        }
        expect(
          (await tester.runAsync(
            () => other.overrides(SettingsScope.global, ''),
          ))!.toJson(),
          initial.toJson(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(database.close);
      },
    );
  }
}
