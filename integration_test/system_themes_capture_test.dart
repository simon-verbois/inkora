import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/appearance_picker.dart';

import '../test/support/ui_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'physical Android system appearance selects both configured defaults',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(
          locale: 'fr',
          systemLightTheme: AppAppearance.pearl,
          systemDarkTheme: AppAppearance.plum,
        ),
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      harness.container.read(routerProvider).go('/settings/appearance');
      await tester.pumpAndSettle();
      Future<void> verify(String mode, AppAppearance appearance) async {
        debugPrint('SYSTEM_THEME_SWITCH: $mode');
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(AppearancePicker)))
              .scaffoldBackgroundColor,
          InkoraTheme.forAppearance(appearance).scaffoldBackgroundColor,
        );
        debugPrint('SYSTEM_THEME_CAPTURE: $mode');
        await Future<void>.delayed(const Duration(seconds: 4));
      }

      await verify('light', AppAppearance.pearl);
      await verify('dark', AppAppearance.plum);
    },
  );
}
