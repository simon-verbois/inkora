import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/appearance_picker.dart';
import 'package:inkora/features/settings/presentation/servers_screen.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all palettes and compact active server details fit $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final harness = await UiHarness.create(tester);
          addTearDown(() => harness.close(tester));
          await harness.mount(tester);
          final router = harness.container.read(routerProvider);
          router.go('/settings/appearance');
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('follow-system-theme')));
          await tester.pumpAndSettle();
          final colors = <Color>{};
          for (final appearance in AppAppearance.values.skip(1)) {
            final tile = find.byKey(ValueKey('theme-${appearance.name}'));
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            await tester.tap(tile);
            await tester.pumpAndSettle();
            colors.add(
              Theme.of(tester.element(find.byType(AppearancePicker)))
                  .scaffoldBackgroundColor,
            );
            expect(
              (await tester.runAsync(
                () => UiPreferencesStore(harness.database).watch().first,
              ))!.appearance,
              appearance,
            );
            expect(tester.takeException(), isNull);
          }
          expect(colors, hasLength(10));
          final selectors = tester
              .widgetList<SegmentedButton<int>>(
                find.byType(SegmentedButton<int>),
              )
              .toList();
          expect(selectors, hasLength(2));
          expect(selectors.every((s) => !s.showSelectedIcon), isTrue);
          expect(selectors[0].segments.map((s) => s.value), [2, 3, 4]);
          expect(selectors[1].segments.map((s) => s.value), [5, 6, 7]);
          expect(find.byKey(const Key('panel-opacity')), findsNothing);
          router.go('/settings/servers');
          await tester.pumpAndSettle();
          expect(find.byType(ServersScreen), findsOneWidget);
          expect(find.text('Connection'), findsNothing);
          expect(find.text('Server connected'), findsNothing);
          expect(find.text('Active account'), findsOneWidget);
          expect(find.byIcon(InkIcons.checkCircle), findsWidgets);
          expect(find.text('Sign out'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Add server'),
            160,
            scrollable: find
                .descendant(
                  of: find.byType(ServersScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }
}
