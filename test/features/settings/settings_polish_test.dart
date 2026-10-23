import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_reset_button.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/reader/domain/gesture_zones.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final section in ['appearance', 'accessibility', 'gestures']) {
    testWidgets(
      '$section reset confirms and changes only its own preferences',
      (tester) async {
        final original = UiPreferences(
          appearance: AppAppearance.plum,
          systemLightTheme: AppAppearance.rose,
          homePortraitColumns: 4,
          homeLandscapeColumns: 7,
          hideTags: false,
          textScale: 1.2,
          reduceMotion: true,
          locale: 'en',
          gestures: GestureZones.forPreset(GesturePreset.fullPage),
        );
        final harness = await UiHarness.create(tester, preferences: original);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        harness.container.read(routerProvider).go('/settings/$section');
        await tester.pumpAndSettle();
        final reset = find
            .descendant(
              of: find.byType(SettingsResetButton),
              matching: find.byType(TextButton),
            )
            .first;
        await tester.tap(reset);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(
          harness.container.read(uiPreferencesProvider).requireValue.toJson(),
          original.copyWith(setupCompleted: true).toJson(),
        );
        await tester.tap(reset);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ink-confirm-accept')));
        await tester.pumpAndSettle();
        final saved = harness.container
            .read(uiPreferencesProvider)
            .requireValue;
        expect(saved.locale, 'en');
        if (section == 'appearance') {
          expect(saved.appearance, AppAppearance.system);
          expect(saved.hideTags, true);
          expect(saved.textScale, original.textScale);
          expect(saved.gestures, original.gestures);
        }
        if (section == 'accessibility') {
          expect(saved.textScale, 1);
          expect(saved.reduceMotion, false);
          expect(saved.appearance, original.appearance);
          expect(saved.gestures, original.gestures);
        }
        if (section == 'gestures') {
          expect(saved.gestures, const GestureZones());
          expect(saved.appearance, original.appearance);
          expect(saved.textScale, original.textScale);
        }
        await harness.close(tester);
      },
    );
  }
  testWidgets(
    'reading profile list has only enabled libraries and no global editor entry',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await tester.runAsync(
        () => LibraryVisibilityStore(
          harness.database,
          harness.repository.store.accountId,
        ).save({'library-a'}),
      );
      await harness.mount(tester);
      harness.container.read(routerProvider).go('/settings/reading');
      await tester.pumpAndSettle();
      expect(find.text('Manga shelf'), findsOneWidget);
      expect(find.text('Graphic novels'), findsNothing);
      expect(
        tester
            .widgetList<InkSettingsRow>(find.byType(InkSettingsRow))
            .where((row) => row.title == 'Global defaults'),
        isEmpty,
      );
      await harness.close(tester);
    },
  );
}
