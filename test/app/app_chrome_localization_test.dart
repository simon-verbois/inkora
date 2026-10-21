import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../support/ui_harness.dart';

void main() {
  for (final language in languageNames.keys) {
    testWidgets(
      '$language appearance controls wrap at 320 pixels and 200% text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: language),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        harness.container.read(routerProvider).go('/settings/appearance');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('panel-opacity')), findsNothing);
        expect(
          find.text(AppStrings(language).text('Home covers per row')),
          findsOneWidget,
        );
        for (final key in ['home-portrait-columns', 'home-landscape-columns']) {
          final control = find.byKey(Key(key));
          await Scrollable.ensureVisible(
            tester.element(control),
            alignment: .2,
          );
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget);
          final choices = find.descendant(
            of: control,
            matching: find.byType(SegmentedButton<int>),
          );
          expect(tester.getSize(choices).width, lessThanOrEqualTo(320));
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
