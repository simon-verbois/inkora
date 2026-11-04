import '../../support/reader_preferences.dart';

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
      '${qualityOnly ? 'quality' : 'reading'} edit preserves the other section and account',
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
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
        expect(find.byType(TabBar), findsNothing);
        await chooseReaderPreference(
          tester,
          qualityOnly
              ? 'reader-choice-quality-all-filter-sepia'
              : 'reader-choice-fit-width',
        );
        final saved = (await tester.runAsync(
          () => store.overrides(SettingsScope.global, ''),
        ))!;
        expect(saves, 0);
        if (qualityOnly) {
          expect(saved.mode, ReadingMode.manga);
          expect(saved.spacing, 24);
          expect(
            saved.imageQuality![RasterFormat.png]!.filter,
            VisualFilter.sepia,
          );
          expect(saved.webtoonQuality, WebtoonQuality.saver);
        } else {
          expect(saved.mode, ReadingMode.manga);
          expect(saved.spacing, 24);
          expect(saved.fit, ReadingFit.width);
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
