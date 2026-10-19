import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import 'support/ui_fixture_binding.dart';
import '../test/support/ui_harness.dart';

void main() {
  UiFixtureIntegrationBinding();
  testWidgets('physical sidebar reaches About and opens guided setup', (
    tester,
  ) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(
        locale: 'fr',
        appearance: AppAppearance.pearl,
      ),
    );
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/settings/appearance');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-sidebar-setup')), findsNothing);
    final menu = find.byKey(const Key('settings-sidebar'));
    expect(
      find.descendant(of: menu, matching: find.byType(Scrollbar)),
      findsNothing,
    );
    final scrollable = find
        .descendant(of: menu, matching: find.byType(Scrollable))
        .first;
    final about = find.byKey(const ValueKey('settings-category-about'));
    await tester.scrollUntilVisible(about, 120, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(
      harness.container
          .read(routerProvider)
          .routeInformationProvider
          .value
          .uri
          .path,
      '/settings/about',
    );
    final setup = find.byKey(const Key('about-guided-setup'));
    await tester.ensureVisible(setup);
    await tester.pumpAndSettle();
    await tester.tap(setup);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setup-sidebar')), findsOneWidget);
    await harness.close(tester);
  });
}
