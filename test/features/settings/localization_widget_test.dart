import '../../support/home_navigation.dart';

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
        expect(find.byTooltip(strings.text('Settings')), findsOneWidget);
        expect(find.byTooltip(strings.text('Downloads')), findsOneWidget);
        expect(find.text('Moonlit District'), findsWidgets);
        await openHomeDestination(tester, 'settings');
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Settings')), findsWidgets);
        expect(find.text(strings.text('Gestures')), findsOneWidget);
        for (final group in ['Account', 'Application', 'Data']) {
          expect(find.text(strings.text(group)), findsOneWidget);
        }
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
    // Reader "pages left" phrases agree with their own count.
    expect(AppStrings('en').quantity(1, 'pageLeft'), '1 page left');
    expect(AppStrings('fr').quantity(15, 'pageLeft'), '15 pages restantes');
    expect(polish.quantity(3, 'pageLeft'), '3 strony do końca');
    expect(polish.quantity(15, 'pageLeft'), '15 stron do końca');
    expect(AppStrings('cs').quantity(2, 'pageLeft'), '2 strany do konce');
    expect(AppStrings('ro').quantity(20, 'pageLeft'), '20 de pagini rămase');
  });
}
