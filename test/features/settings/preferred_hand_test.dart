import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';

import '../../support/onboarding_visuals.dart';
import '../library/series_detail_widget_test.dart' show openSeries, reveal;

void main() {
  setUpAll(loadOnboardingFonts);
  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'preferred hand selects, persists and aligns synopsis at 320dp/200%/$locale',
      (tester) async {
        final harness = await openSeries(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          locale: locale.languageCode,
        );
        final toggle = find.byKey(const Key('detail-summary-toggle'));
        await reveal(tester, toggle);
        expect(tester.getRect(toggle).center.dx, greaterThan(160));
        final router = harness.container.read(routerProvider);
        router.go('/settings/accessibility');
        await tester.pumpAndSettle();
        final left = find.byKey(const Key('reader-choice-preferred-hand-left'));
        await tester.ensureVisible(left);
        await tester.pumpAndSettle();
        await tester.tap(left);
        await tester.pumpAndSettle();
        expect(
          harness.container.read(uiPreferencesProvider).requireValue.leftHanded,
          isTrue,
        );
        final restored = await tester.runAsync(
          () => UiPreferencesStore(harness.database).watch().first,
        );
        expect(restored!.leftHanded, isTrue);
        router.go('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        await reveal(tester, toggle);
        expect(tester.getRect(toggle).center.dx, lessThan(160));
        // Changing only the hand does not reset or replace the synopsis state.
        final current = tester.state(find.byType(SeriesSynopsis));
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((p) => p.copyWith(leftHanded: false)),
        );
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SeriesSynopsis)), same(current));
        expect(tester.getRect(toggle).center.dx, greaterThan(160));
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
