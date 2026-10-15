import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  test('message arguments remain data even when they contain placeholders', () {
    expect(
      AppStrings('en').text('{0} · {1}', ['Title {1}', 'value']),
      'Title {1} · value',
    );
  });
  for (final language in languageNames.keys) {
    testWidgets(
      '$language localizes navigation and settings while preserving server titles',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: language),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final strings = AppStrings(language);
        expect(find.text(strings.text('Home')), findsOneWidget);
        expect(find.text('Moonlit District'), findsWidgets);
        await tester.tap(find.byKey(const Key('navigation-settings')));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Settings')), findsWidgets);
        expect(find.text(strings.text('Reading gestures')), findsOneWidget);
        expect(find.text(strings.text('Language')), findsOneWidget);
        harness.container.read(routerProvider).push<void>('/settings/language');
        await tester.pumpAndSettle();
        final picker = find.byType(DropdownButtonFormField<String>);
        expect(find.byIcon(InkIcons.caretDown), findsOneWidget);
        await tester.ensureVisible(picker);
        await tester.pumpAndSettle();
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text(languageNames[language]!).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
  test('quantity grammar follows Polish, Czech and Romanian integer forms', () {
    final polish = AppStrings('pl');
    expect(polish.quantity(1, 'book'), '1 książka');
    expect(polish.quantity(2, 'book'), '2 książki');
    expect(polish.quantity(12, 'book'), '12 książek');
    expect(AppStrings('cs').quantity(3, 'page'), '3 strany');
    expect(AppStrings('ro').quantity(20, 'book'), '20 de cărți');
    expect(polish.quantity(1, 'screen'), '1 ekran');
    expect(polish.quantity(2, 'screen'), '2 ekrany');
    expect(polish.quantity(5, 'screen'), '5 ekranów');
    expect(polish.quantity(1, 'update'), '1 aktualizacja');
    expect(polish.quantity(22, 'update'), '22 aktualizacje');
    expect(polish.quantity(12, 'update'), '12 aktualizacji');
    expect(AppStrings('cs').quantity(3, 'screen'), '3 obrazovky');
    expect(AppStrings('ro').quantity(20, 'update'), '20 de actualizări');
    expect(AppStrings('hu').quantity(4, 'screen'), '4 képernyő');
  });
}
