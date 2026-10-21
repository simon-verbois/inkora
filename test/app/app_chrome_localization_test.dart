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
        final slider = find.byKey(const Key('panel-opacity'));
        await Scrollable.ensureVisible(tester.element(slider), alignment: .2);
        await tester.pumpAndSettle();
        expect(slider.hitTestable(), findsOneWidget);
        expect(
          find.text(AppStrings(language).text('Floating navigation')),
          findsNothing,
        );
        expect(
          find.text(AppStrings(language).text('Panel opacity')),
          findsOneWidget,
        );
        expect(
          find.text(
            AppStrings(language).text(
              'Applies to navigation, headers and search. Text stays fully opaque.',
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
