import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/onboarding_visuals.dart';
import 'reader_settings_tabs_test.dart' show openSheet, settle;

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'book-only templates preserve parent settings at $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.runAsync(loadOnboardingFonts);
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final store = ReaderStore(db, 'book-only');
          final manifest = ReaderManifest(
            accountId: store.accountId,
            libraryId: 'library',
            seriesId: 'series',
            bookId: 'epub',
            revision: 'r1',
            title: 'Fixture',
            documentType: 'application/epub+zip',
            pages: [PageDimensions(1, 1)],
          );
          final parents = {
            SettingsScope.global: const ReadingOverrides(
              mode: ReadingMode.ebook,
              ebook: {'lineHeight': 1.8, 'fontSize': 1.8},
            ),
            SettingsScope.library: const ReadingOverrides(
              ebook: {'margins': 1.4, 'scroll': true},
            ),
            SettingsScope.series: const ReadingOverrides(
              ebook: {'justify': true, 'publisherStyles': false},
            ),
          };
          await tester.runAsync(() async {
            for (final entry in parents.entries) {
              await store.saveOverrides(entry.key, switch (entry.key) {
                SettingsScope.global => '',
                SettingsScope.library => 'library',
                _ => 'series',
              }, entry.value);
            }
          });
          const locale = Locale('fr');
          final strings = AppStrings('fr');
          await openSheet(
            tester,
            store,
            manifest,
            locale: locale,
            bookOnly: true,
          );
          expect(find.text(strings.text('Reading preferences')), findsNothing);
          expect(
            tester.getTopLeft(find.byType(TabBar)).dy,
            closeTo(tester.getTopLeft(find.byType(ReaderSettingsSheet)).dy, 1),
          );
          expect(find.byKey(const Key('reader-settings-scope')), findsNothing);
          expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
          final templates = find.text(strings.text('Templates'));
          await tester.ensureVisible(templates);
          await tester.tap(templates);
          await tester.pumpAndSettle();
          for (final style in EbookStyle.values) {
            final card = find.byKey(ValueKey('ebook-style-${style.name}'));
            await tester.ensureVisible(card);
            await tester.pumpAndSettle();
            await tester.tap(card);
            await settle(tester);
            final saved = (await tester.runAsync(
              () => store.settings(manifest).first,
            ))!;
            expect(style.matches(saved), true);
            expect(saved.ebook.fontChoice, style.fontChoice);
            expect(saved.ebook.fontSize, 1.0);
            expect(saved.ebook.publisherStyles, true);
            // The existing manual values survive, ready if publisher styles are
            // deliberately disabled later. Templates must not invent geometry.
            expect(saved.ebook.lineHeight, 1.8);
            expect(saved.ebook.margins, 1.4);
            expect(saved.ebook.justify, true);
            expect(saved.ebook.scroll, true);
            final layers = (await tester.runAsync(
              () => store.preferenceLayers(
                libraryId: 'library',
                seriesId: 'series',
                bookId: 'epub',
              ),
            ))!;
            for (final entry in parents.entries) {
              expect(layers[entry.key]!.toJson(), entry.value.toJson());
            }
            expect(layers[SettingsScope.book]!.ebook!['font'], style.font);
            for (final field in ['lineHeight', 'margins', 'justify']) {
              expect(
                layers[SettingsScope.book]!.ebook!.containsKey(field),
                false,
              );
            }
          }
          final appearance = find.text(strings.text('Appearance'));
          await tester.ensureVisible(appearance);
          await tester.tap(appearance);
          await tester.pumpAndSettle();
          if (size.width == 390 && scale == 1) {
            await captureOnboarding(
              tester,
              find.byKey(const Key('preferences-capture')),
              'reader-book-preferences-fr',
            );
          }
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await openSheet(
            tester,
            store,
            manifest,
            locale: locale,
            bookOnly: true,
          );
          expect(find.text(strings.text('Reading preferences')), findsNothing);
          expect(
            tester.getTopLeft(find.byType(TabBar)).dy,
            closeTo(tester.getTopLeft(find.byType(ReaderSettingsSheet)).dy, 1),
          );
          expect(find.byKey(const Key('reader-settings-scope')), findsNothing);
          expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
          expect(find.text('Atkinson Hyperlegible'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
