import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';

import '../../support/onboarding_visuals.dart';
import '../library/series_detail_widget_test.dart' show openSeries, reveal;

void main() {
  setUpAll(loadOnboardingFonts);
  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'synopsis expansion is centered without a hand setting at 320dp/200%/$locale',
      (tester) async {
        final harness = await openSeries(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          locale: locale.languageCode,
        );
        final toggle = find.byKey(const Key('detail-summary-toggle'));
        await reveal(tester, toggle);
        expect(tester.getRect(toggle).center.dx, closeTo(160, 1));
        final router = harness.container.read(routerProvider);
        router.go('/settings/accessibility');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('reader-choice-preferred-hand-left')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('reader-choice-preferred-hand-right')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
