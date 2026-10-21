import '../test/support/home_navigation.dart';
import 'support/ui_fixture_binding.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';

import '../test/support/ui_harness.dart';
import '../test/app/predictive_back_widget_test.dart' as predictive;
import '../test/app/reader_shortcut_shell_test.dart' as shortcut;
import '../test/features/library/library_home_navigation_test.dart'
    as navigation;
import '../test/features/library/home_shelves_widget_test.dart' as home;
import '../test/features/library/discovery_widget_test.dart' as removed;

void main() {
  final binding = UiFixtureIntegrationBinding();
  if (!const bool.fromEnvironment('NATIVE_NAV_EDGE_ONLY')) {
    navigation.main();
    home.main();
    removed.main();
    predictive.main();
    shortcut.main();
  }
  if (const bool.fromEnvironment('NATIVE_NAV_EDGE')) {
    testWidgets(
      'real Android edge returns series details to the unified library',
      (tester) async {
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        router.go('/');
        await tester.pumpAndSettle();
        router.push<void>('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueDetailScreen), findsOneWidget);
        debugPrint('NAV_NATIVE_EDGE_READY');
        for (
          var attempt = 0;
          attempt < 150 && tester.any(find.byType(CatalogueDetailScreen));
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(router.routeInformationProvider.value.uri.path, '/');
        // Imperative pages need not change GoRouter's reported URI. Observe the
        // departing widget and allow the native reverse animation to complete.
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueDetailScreen), findsNothing);
        await openHomeDestination(tester, 'settings');
        await tester.pumpAndSettle();
        expect(
          tester.widget<SettingsScreen>(find.byType(SettingsScreen)).section,
          'appearance',
        );
        expect(tester.takeException(), isNull);
        debugPrint('NAV_NATIVE_EDGE_RETAINED');
        await harness.close(tester);
      },
    );
  }
}
