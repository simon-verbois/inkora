import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final width in [390.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'server selection persists and updates catalogue at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(tester);
          addTearDown(() => harness.close(tester));
          await harness.mount(tester, textScale: scale);
          harness.container.read(routerProvider).go('/settings/servers');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Libraries to display'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Libraries to display'));
          await tester.pumpAndSettle();
          final second = find.byKey(
            const ValueKey('visible-library-library-b'),
          );
          await tester.ensureVisible(second);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(second).value, isTrue);
          await tester.tap(second);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(second).value, isFalse);
          final filtered = await tester.runAsync(
            () => harness.repository.store.read(
              const CatalogueQuery(kind: CatalogueKind.series),
            ),
          );
          expect(filtered!.items.map((item) => item.id), ['series-a']);
          harness.container.read(routerProvider).go('/libraries');
          await tester.pumpAndSettle();
          expect(find.text('Atlas Nine'), findsNothing);
          expect(find.text('Moonlit District'), findsWidgets);
          harness.container.read(routerProvider).go('/settings/servers');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Libraries to display'));
          await tester.pumpAndSettle();
          if (second.evaluate().isEmpty) {
            await tester.tap(find.text('Libraries to display'));
            await tester.pumpAndSettle();
          }
          expect(tester.widget<CheckboxListTile>(second).value, isFalse);
          final all = find.byKey(const Key('all-accessible-libraries'));
          await tester.ensureVisible(all);
          await tester.pumpAndSettle();
          await tester.tap(all);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(second).value, isTrue);
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }

  for (final locale in [
    'en',
    'fr',
    'de',
    'es',
    'it',
    'pl',
    'nl',
    'pt',
    'ro',
    'el',
    'hu',
    'cs',
  ]) {
    testWidgets(
      'localized visibility controls wrap at 200% on phone: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        harness.container.read(routerProvider).go('/settings/servers');
        await tester.pumpAndSettle();
        final panel = find.byKey(const Key('library-visibility'));
        await tester.ensureVisible(panel);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: panel, matching: find.byType(ListTile)).first,
        );
        await tester.pumpAndSettle();
        final all = find.byKey(const Key('all-accessible-libraries'));
        await tester.ensureVisible(all);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(all).value, isTrue);
        expect(find.text('Graphic novels'), findsOneWidget);
        if (locale != 'en') {
          expect(find.text('Show all accessible libraries'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
