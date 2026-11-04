import '../../support/reader_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/domain/gesture_zones.dart';

import '../../support/onboarding_visuals.dart';
import '../../support/ui_harness.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final (size, scale, language) in [
    for (final locale in AppStrings.supportedLocales)
      (const Size(320, 640), 2.0, locale.languageCode),
    (const Size(390, 844), 1.0, 'fr'),
    (const Size(1024, 768), 1.0, 'fr'),
    (const Size(667, 375), 1.0, 'fr'),
  ]) {
    testWidgets(
      'device-language welcome keeps actions after its features at $size/$scale/$language',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.localeTestValue = AppStrings.localeFor(
          language,
        );
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(
            locale: 'en',
            setupStep: 0,
            appearance: AppAppearance.amoled,
            reduceMotion: true,
          ),
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((p) => p.copyWith(setupCompleted: false)),
        );
        const capture = Key('setup-capture');
        await harness.mount(tester, textScale: scale, captureKey: capture);
        final next = find.byKey(const Key('setup-next'));
        final back = find.byKey(const Key('setup-back'));
        final scrollable = find.descendant(
          of: find.byKey(const Key('setup-introduction-scroll')),
          matching: find.byType(Scrollable),
        );
        if (scale == 2 || size.height < 500) {
          expect(next.hitTestable(), findsNothing);
        }
        expect(
          find.descendant(
            of: find.byKey(const Key('setup-introduction-scroll')),
            matching: find.text(AppStrings(language).text('Welcome to Inkora')),
          ),
          findsOneWidget,
        );
        if (size.width == 390) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'welcome-top-fr',
          );
        }
        await tester.scrollUntilVisible(next, 200, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(next.hitTestable(), findsOneWidget);
        expect(find.descendant(of: scrollable, matching: next), findsOneWidget);
        expect(find.descendant(of: scrollable, matching: back), findsOneWidget);
        final strings = AppStrings(language);
        expect(
          tester.getTopLeft(next).dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.text(
                    strings.text(
                      'Reading progress is saved on your device and synchronized with Komga when connected.',
                    ),
                  ),
                )
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
        if (size.width == 390) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'welcome-bottom-fr',
          );
        }
        expect(tester.widget<OutlinedButton>(back).onPressed, isNull);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          harness.container.read(uiPreferencesProvider).requireValue.setupStep,
          1,
        );
        expect(
          harness.container
              .read(uiPreferencesProvider)
              .requireValue
              .setupCompleted,
          isFalse,
        );
        expect(
          harness.container.read(uiPreferencesProvider).requireValue.locale,
          'en',
        );
        expect(find.text('Language'), findsNothing);
        expect(find.text('Appearance'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, scale, language) in [
    for (final locale in AppStrings.supportedLocales)
      (const Size(320, 640), 2.0, locale.languageCode),
    (const Size(390, 844), 1.0, 'fr'),
    (const Size(1024, 768), 1.0, 'de'),
  ]) {
    testWidgets(
      'setup finishes with a short message at $size/$scale/$language',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(
            locale: language,
            setupStep: 7,
            appearance: AppAppearance.amoled,
          ),
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((p) => p.copyWith(setupCompleted: false)),
        );
        const capture = Key('setup-completion-capture');
        await harness.mount(tester, textScale: scale, captureKey: capture);
        final strings = AppStrings(language);
        expect(
          find.text(strings.text('Setup is complete. Enjoy your reading!')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('setup-introduction-scroll')),
          findsNothing,
        );
        final next = find.byKey(const Key('setup-next'));
        expect(next.hitTestable(), findsOneWidget);
        if (language == 'fr') {
          await captureOnboarding(tester, find.byKey(capture), 'completion-fr');
        }
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          harness.container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
        expect(
          harness.container
              .read(uiPreferencesProvider)
              .requireValue
              .setupCompleted,
          isTrue,
        );
        await harness.close(tester);
      },
    );
  }

  testWidgets(
    'setup library editor has a local Back and ordered sections for every mode',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(
          locale: 'fr',
          setupStep: 3,
          appearance: AppAppearance.amoled,
        ),
      );
      addTearDown(() => harness.close(tester));
      await tester.runAsync(
        () =>
            UiPreferencesStore(harness.database)
                .update((p) => p.copyWith(setupCompleted: false)),
      );
      const capture = Key('setup-library-capture');
      await harness.mount(tester, captureKey: capture);
      await tester.tap(find.text('Manga shelf'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-next')), findsNothing);
      expect(find.byKey(const Key('setup-back')), findsNothing);
      expect(
        find.byKey(const Key('setup-library-back')).hitTestable(),
        findsOneWidget,
      );
      for (final mode in ['manga', 'comics', 'webtoon', 'ebook']) {
        final choice = find.byKey(const Key('reader-mode-selector'));
        await chooseSetupMode(tester, mode);
        expect(find.byType(TabBar), findsNothing);
        expect(find.byKey(const Key('reader-settings-scope')), findsNothing);
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
        if (mode == 'ebook') {
          Scrollable.of(tester.element(choice)).position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(find.text('Templates'), findsOneWidget);
          expect(
            tester.getTopLeft(choice).dy,
            lessThan(tester.getTopLeft(find.text('Templates')).dy),
          );
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'setup-library-ebook-fr',
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const Key('setup-library-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-next')).hitTestable(), findsOneWidget);
      expect(find.text('Manga shelf'), findsOneWidget);
      await harness.close(tester);
    },
  );

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(1024, 768), 1.0),
  ]) {
    testWidgets(
      'custom is fourth, previews locally, cancels and saves once at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: const UiPreferences(
            locale: 'fr',
            setupStep: 2,
            appearance: AppAppearance.amoled,
          ),
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((p) => p.copyWith(setupCompleted: false)),
        );
        const capture = Key('gestures-capture');
        await harness.mount(tester, textScale: scale, captureKey: capture);
        expect(
          find.byType(DropdownButtonFormField<GesturePreset>),
          findsOneWidget,
        );
        expect(find.byKey(const Key('gesture-preview')), findsNothing);
        final original = harness.container
            .read(uiPreferencesProvider)
            .requireValue
            .gestures;
        var emissions = 0;
        final subscription = harness.container.listen(
          uiPreferencesProvider,
          (_, _) => emissions++,
        );
        addTearDown(subscription.close);
        Future<void> open() => chooseGesturePreset(tester, 'custom');

        await open();
        final slider = find.byKey(const ValueKey('gesture-edge-Left edge'));
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        await tester.drag(slider, const Offset(60, 0));
        await tester.pumpAndSettle();
        final changed = tester.widget<Slider>(slider).value;
        expect(changed, isNot(original.left));
        final preview = find.descendant(
          of: find.byKey(const Key('gesture-preview')),
          matching: find.byType(Positioned),
        );
        expect(tester.widget<Positioned>(preview).left, changed);
        expect(emissions, 0);
        await tester.ensureVisible(
          find.byKey(const Key('gesture-custom-cancel')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gesture-custom-cancel')));
        await tester.pumpAndSettle();
        expect(
          harness.container.read(uiPreferencesProvider).requireValue.gestures,
          original,
        );
        expect(emissions, 0);
        await open();
        expect(tester.widget<Slider>(slider).value, original.left);
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        await tester.drag(slider, const Offset(60, 0));
        await tester.pumpAndSettle();
        final savedLeft = tester.widget<Slider>(slider).value;
        expect(emissions, 0);
        if (size.width == 390) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'gestures-custom-fr',
          );
        }
        await tester.ensureVisible(
          find.byKey(const Key('gesture-custom-save')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gesture-custom-save')));
        await tester.pumpAndSettle();
        final saved = harness.container
            .read(uiPreferencesProvider)
            .requireValue
            .gestures;
        expect(saved.preset, GesturePreset.custom);
        expect(saved.left, savedLeft);
        expect(saved.right, original.right);
        expect(emissions, 1);
        expect(find.byKey(const Key('gesture-preview')), findsNothing);
        expect(tester.takeException(), isNull);
        // Reopening ordinary Settings retains its reset action.
        harness.container.read(routerProvider).go('/settings/gestures');
        await tester.pumpAndSettle();
      },
    );
  }
}
