import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/features/settings/presentation/settings_sections.dart';

import '../../support/ui_harness.dart';

void main() {
  test('four groups, distinct icons and a path for every section', () {
    expect(SettingsGroup.values.map((g) => g.label), [
      'Account',
      'Reading',
      'Application',
      'Data',
    ]);
    expect(
      settingsSections.map((s) => s.icon).toSet(),
      hasLength(settingsSections.length),
      reason: 'one distinct icon per section',
    );
    expect(settingsSections.map((s) => s.id).toSet(), {
      'servers',
      'reading',
      'gestures',
      'quality',
      'appearance',
      'language',
      'accessibility',
      'downloads',
      'transfer',
      'about',
    });
    // Sections are listed in group order.
    final order = settingsSections.map((s) => s.group.index).toList();
    expect(order, [...order]..sort());
    final strings = AppStrings('en');
    expect(
      settingsSectionPath(
        strings,
        settingsSections.firstWhere((s) => s.id == 'gestures'),
      ),
      'Reading › Gestures',
    );
    expect(searchSettings(strings, 'gest').map((s) => s.id), ['gestures']);
    // A group name finds its sections.
    expect(searchSettings(strings, 'data').map((s) => s.id), [
      'transfer',
      'about',
    ]);
    expect(searchSettings(strings, ''), hasLength(settingsSections.length));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'phone settings index groups sections and searches with paths at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        final router = harness.container.read(routerProvider);
        router.go('/settings');
        await tester.pumpAndSettle();
        final list = find.byWidget(
          tester.widget<Scrollable>(
            find
                .ancestor(
                  of: find.byType(TextField),
                  matching: find.byType(Scrollable),
                )
                .first,
          ),
        );
        for (final group in SettingsGroup.values) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('settings-group-${group.name}')),
            150,
            scrollable: list,
          );
          expect(
            find.byKey(ValueKey('settings-group-${group.name}')),
            findsOneWidget,
          );
        }
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -150,
          scrollable: list,
        );
        await tester.pumpAndSettle();
        // Exactly one search field, with the shared hint.
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search settings'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'gestures');
        await tester.pumpAndSettle();
        expect(find.text('Reading › Gestures'), findsOneWidget);
        // Trailing current value where it is cheap: the gesture preset.
        expect(find.text('Balanced'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings-group-account')),
          findsNothing,
        );
        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('settings-no-results')), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'gestures');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reading › Gestures'));
        await tester.pumpAndSettle();
        // The page title equals the menu label and is not repeated in-page.
        expect(
          find.descendant(
            of: find.byType(InkScreenHeader),
            matching: find.text('Gestures'),
          ),
          findsOneWidget,
        );
        expect(find.text('Gestures'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets('wide settings sidebar uses the same groups and search paths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/settings/downloads');
    await tester.pumpAndSettle();
    final sidebar = find.byKey(const Key('settings-sidebar'));
    expect(sidebar, findsOneWidget);
    for (final group in SettingsGroup.values) {
      expect(
        find.descendant(
          of: sidebar,
          matching: find.byKey(ValueKey('settings-group-${group.name}')),
        ),
        findsOneWidget,
      );
    }
    // The downloads page shows no second "Download settings" title.
    expect(find.text('Download settings'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-sidebar-search-toggle')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('settings-sidebar-search'));
    expect(
      find.descendant(of: field, matching: find.text('Search settings')),
      findsOneWidget,
    );
    await tester.enterText(field, 'image');
    await tester.pumpAndSettle();
    expect(find.text('Reading › Image quality'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
