import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final language in languageNames.keys) {
    for (final (size, scale) in [
      (const Size(320, 640), 2.0),
      (const Size(1024, 768), 1.0),
    ]) {
      testWidgets('$language quality choices fit $size/$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: language),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        harness.container.read(routerProvider).go('/settings/quality');
        await tester.pumpAndSettle();
        final chip = find.byKey(
          const Key('reader-choice-quality-all-sampling-nearest'),
        );
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings(language).text('Nearest neighbour')),
          findsWidgets,
        );
        await tester.tap(chip);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
        expect(find.text(AppStrings(language).text('Save')), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }
  testWidgets(
    'reading groups global and library editors and retires sync navigation',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Synchronization'), findsNothing);
      expect(find.text('Library defaults'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Image quality'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Image quality'), findsOneWidget);
      router.push<void>('/settings/reading');
      await tester.pumpAndSettle();
      expect(find.text('Global defaults'), findsWidgets);
      expect(find.text('Manga shelf'), findsOneWidget);
      await tester.tap(find.text('Manga shelf'));
      await tester.pumpAndSettle();
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Webtoon image quality'), findsNothing);
      expect(find.text('Image scaling'), findsNothing);
      // Legacy synchronization entry points go back to settings.
      router.go('/settings/sync');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      await harness.close(tester);
    },
  );
}
