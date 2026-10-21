import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/presentation/setup_screen.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  testWidgets('compact settings opens guided setup only from About', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Guided setup'), findsNothing);
    final scrollable = find.byWidget(
      tester.widget<Scrollable>(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(Scrollable),
            )
            .first,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('About Inkora'),
      180,
      scrollable: scrollable,
    );
    // Scroll to the end so the last row clears the floating navigation bar.
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Inkora'));
    await tester.pumpAndSettle();
    final setup = find.byKey(const Key('about-guided-setup'));
    await tester.ensureVisible(setup);
    await tester.pumpAndSettle();
    await tester.tap(setup);
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(
      tester.widget<SetupScreen>(find.byType(SetupScreen)).editing,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
  for (final locale in AppStrings.supportedLocales) {
    testWidgets('tablet search is revealed on demand and clears in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1205, 753);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        preferences: UiPreferences(locale: locale.languageCode),
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester, textScale: 1.3);
      harness.container.read(routerProvider).go('/settings/quality');
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('settings-sidebar-search-toggle'));
      final field = find.byKey(const Key('settings-sidebar-search'));
      final heading = find.byKey(const Key('settings-sidebar-heading'));
      final strings = AppStrings(locale.languageCode);
      expect(field, findsNothing);
      expect(find.byTooltip(strings.text('Search settings')), findsOneWidget);
      expect(
        tester.getCenter(toggle).dx,
        greaterThan(tester.getCenter(heading).dx),
      );
      expect(
        (tester.getCenter(toggle).dy - tester.getCenter(heading).dy).abs(),
        lessThan(1),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.getRect(field).overlaps(tester.getRect(heading)), isTrue);
      await tester.enterText(field, strings.text('Language'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-category-language')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-category-appearance')),
        findsNothing,
      );
      expect(
        harness.container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/settings/quality',
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      // The bottom overlay reduces the available category height; long
      // localized rows may be lazily built below the first viewport.
      final categories = find
          .descendant(
            of: find.byKey(const Key('settings-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-category-appearance')),
        100,
        scrollable: categories,
      );
      expect(
        find.byKey(const ValueKey('settings-category-appearance')),
        findsOneWidget,
      );
      tester.state<ScrollableState>(categories).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'search covers heading from the icon with reduced motion $reducedMotion',
      (tester) async {
        tester.view.physicalSize = const Size(1205, 753);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(reduceMotion: reducedMotion),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        harness.container.read(routerProvider).go('/settings/quality');
        await tester.pumpAndSettle();
        final toggle = find.byKey(const Key('settings-sidebar-search-toggle'));
        final heading = find.byKey(const Key('settings-sidebar-heading'));
        final field = find.byKey(const Key('settings-sidebar-search'));
        final reveal = find.byKey(const Key('settings-sidebar-search-reveal'));
        final closedRect = tester.getRect(heading);
        final categoryTop = tester.getTopLeft(
          find.byKey(const ValueKey('settings-category-servers')),
        );
        await tester.tap(toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final intermediateClip = tester
            .widget<ClipRect>(reveal)
            .clipper!
            .getClip(tester.getSize(reveal));
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pumpAndSettle();
        expect(tester.getRect(heading), closedRect);
        expect(
          tester.getTopLeft(
            find.byKey(const ValueKey('settings-category-servers')),
          ),
          categoryTop,
        );
        expect(tester.getRect(field).overlaps(closedRect), isTrue);
        expect(
          tester.getRect(field).right,
          lessThanOrEqualTo(tester.getRect(toggle).left),
        );
        if (reducedMotion) {
          expect(intermediateClip.left, 0);
        } else {
          expect(intermediateClip.left, greaterThan(0));
          expect(intermediateClip.left, lessThan(intermediateClip.right));
        }
        expect(
          tester
              .widget<ClipRect>(reveal)
              .clipper!
              .getClip(tester.getSize(reveal))
              .left,
          0,
        );
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final editableState = tester.state<EditableTextState>(editable);
        tester.view.viewInsets = const FakeViewPadding(bottom: 503);
        await tester.pumpAndSettle();
        expect(tester.state<EditableTextState>(editable), same(editableState));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(tester.state<EditableTextState>(editable), same(editableState));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.getRect(heading), closedRect);
        expect(field, findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
  for (final height in [600.0, 753.0]) {
    testWidgets(
      'sidebar scrolls without a scrollbar and reaches final category at $height',
      (tester) async {
        tester.view.physicalSize = Size(1205, height);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(top: 64, bottom: 40);
        tester.view.padding = const FakeViewPadding(top: 64, bottom: 40);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final harness = await UiHarness.create(
          tester,
          preferences: const UiPreferences(locale: 'fr'),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        final menu = find.byKey(const Key('settings-sidebar'));
        expect(find.byKey(const Key('settings-sidebar-search')), findsNothing);
        expect(
          find.byKey(const Key('settings-sidebar-divider')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: menu, matching: find.byType(Scrollbar)),
          findsNothing,
        );
        final scrollable = find
            .descendant(of: menu, matching: find.byType(Scrollable))
            .first;
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
        expect(find.byKey(const Key('settings-sidebar-setup')), findsNothing);
        final about = find.byKey(const ValueKey('settings-category-about'));
        await tester.scrollUntilVisible(about, 120, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(about.hitTestable(), findsOneWidget);
        await tester.tap(about);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/settings/about',
        );
        final setup = find.byKey(const Key('about-guided-setup'));
        await tester.ensureVisible(setup);
        await tester.pumpAndSettle();
        expect(setup.hitTestable(), findsOneWidget);
        await tester.tap(setup);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('setup-sidebar')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
