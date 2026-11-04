import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/reader/domain/gesture_zones.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final section in ['appearance', 'accessibility', 'gestures']) {
    testWidgets('$section has no reset and preserves saved preferences', (
      tester,
    ) async {
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
      expect(find.text('Reset to default'), findsNothing);
      expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
      expect(
        harness.container.read(uiPreferencesProvider).requireValue.toJson(),
        original.copyWith(setupCompleted: true).toJson(),
      );
      await harness.close(tester);
    });
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
