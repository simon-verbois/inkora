import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/appearance_picker.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1200, 800)]) {
    testWidgets(
      'system palettes follow brightness and retain fixed choices at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        Future<void> select(String name) async {
          final tile = find.byKey(ValueKey('theme-$name'));
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Color background() =>
            Theme.of(tester.element(find.byType(AppearancePicker)))
                .scaffoldBackgroundColor;
        Future<UiPreferences> saved() async => (await tester.runAsync(
          () => UiPreferencesStore(harness.database).watch().first,
        ))!;
        await select('pearl');
        await select('plum');
        final preferences = await saved();
        expect(preferences.appearance, AppAppearance.system);
        expect(preferences.systemLightTheme, AppAppearance.pearl);
        expect(preferences.systemDarkTheme, AppAppearance.plum);
        expect(
          background(),
          InkoraTheme.forAppearance(AppAppearance.pearl)
              .scaffoldBackgroundColor,
        );
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          background(),
          InkoraTheme.forAppearance(AppAppearance.plum).scaffoldBackgroundColor,
        );
        // Reopening retains both selected defaults without disabling system mode.
        router.go('/');
        await tester.pumpAndSettle();
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('follow-system-theme')),
              )
              .value,
          isTrue,
        );
        await tester.ensureVisible(
          find.byKey(const Key('follow-system-theme')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('follow-system-theme')));
        await tester.pumpAndSettle();
        expect((await saved()).appearance, AppAppearance.plum);
        await select('rose');
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          background(),
          InkoraTheme.forAppearance(AppAppearance.rose).scaffoldBackgroundColor,
        );
        final toggle = find.byKey(const Key('follow-system-theme'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          background(),
          InkoraTheme.forAppearance(AppAppearance.plum).scaffoldBackgroundColor,
        );
        expect((await saved()).appearance, AppAppearance.system);
        await harness.close(tester);
      },
    );
  }
}
