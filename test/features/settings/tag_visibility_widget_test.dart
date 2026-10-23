import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  test('tag visibility defaults and portable preference round trip', () {
    expect(const UiPreferences().hideTags, isTrue);
    expect(UiPreferences.fromJson({}).hideTags, isTrue);
    for (final hidden in [true, false]) {
      final value = const UiPreferences().copyWith(hideTags: hidden);
      expect(UiPreferences.fromJson(value.toJson()).hideTags, hidden);
      expect(value.copyWith(locale: 'fr').hideTags, hidden);
    }
  });
  for (final locale in languageNames.keys) {
    testWidgets(
      'tag toggle persists and controls book/series metadata at 320dp/200%/$locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale),
          resumeEntries: const [],
          catalogue: [
            const CatalogueItem(
              kind: CatalogueKind.library,
              id: 'library-a',
              title: 'Shelf',
            ),
            const CatalogueItem(
              kind: CatalogueKind.series,
              id: 'series',
              libraryId: 'library-a',
              title: 'Fixture series',
              metadata: CatalogueMetadata(
                tags: ['score: 8.4'],
                publisher: 'Fixture publisher',
              ),
            ),
            const CatalogueItem(
              kind: CatalogueKind.book,
              id: 'book',
              libraryId: 'library-a',
              title: 'Fixture book',
              seriesId: 'series',
              metadata: CatalogueMetadata(
                mediaType: 'application/epub+zip',
                tags: ['score: 8.4'],
                publisher: 'Fixture publisher',
              ),
            ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        final router = harness.container.read(routerProvider);
        for (final kind in ['series', 'book']) {
          router.go('/catalogue/$kind/$kind');
          await tester.pumpAndSettle();
          expect(find.text('Fixture $kind'), findsOneWidget);
          expect(find.text('score: 8.4'), findsNothing);
        }
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        final setting = find.byKey(const Key('hide-tags'));
        final toggle = find.descendant(
          of: setting,
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(setting).value, isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final restored = (await tester.runAsync(
          () => UiPreferencesStore(harness.database).watch().first,
        ))!;
        expect(restored.hideTags, isFalse);
        await tester.pumpAndSettle();
        expect(
          harness.container.read(uiPreferencesProvider).asData?.value.hideTags,
          isFalse,
        );
        for (final kind in ['series', 'book']) {
          router.go('/catalogue/$kind/$kind');
          await tester.pumpAndSettle();
          if (kind == 'series') {
            await tester.drag(
              find.byType(CustomScrollView).last,
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
          }
          expect(find.text('score: 8.4'), findsOneWidget, reason: kind);
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
