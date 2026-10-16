import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'interface slider allows a bounded reduction and persists only on release at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: const UiPreferences(setupCompleted: true, locale: 'en'),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        harness.container.read(routerProvider).go('/settings/accessibility');
        await tester.pumpAndSettle();
        final finder = find.byKey(const Key('interface-text-scale'));
        final slider = tester.widget<Slider>(finder);
        expect(slider.min, .85);
        expect(slider.max, 1.3);
        final store = UiPreferencesStore(harness.database);
        final gesture = await tester.startGesture(
          tester.getTopLeft(finder) + const Offset(24, 24),
        );
        await gesture.moveBy(const Offset(15, 0));
        await tester.pump();
        expect(
          (await tester.runAsync(() => store.watch().first))!.textScale,
          1,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        final restored = (await tester.runAsync(() => store.watch().first))!;
        expect(restored.textScale, lessThan(1));
        expect(
          UiPreferences.fromJson(restored.toJson()).textScale,
          restored.textScale,
        );
        for (final invalid in [.5, 2.0, double.nan, double.infinity]) {
          expect(UiPreferences.fromJson({'textScale': invalid}).textScale, 1);
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
