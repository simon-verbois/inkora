import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/appearance_picker.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/ui_harness.dart';

void main() {
  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
  }

  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets(
    'tablet settings keep one header level and the bottom navigation while editors survive resize',
    (tester) async {
      size(tester, const Size(1200, 800));
      resetView(tester);
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(locale: 'en'),
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
      expect(find.byType(AppearancePicker), findsOneWidget);
      // One header level: wide panes use the sidebar heading (no screen
      // header, no Back); other windows use the page's own screen header.
      // Settings keeps its own title; Home owns the shared logo band.
      void checkShellHeader() {
        final size = tester.view.physicalSize;
        final wide = size.width >= 1000 && size.width > size.height;
        final rail = find.byKey(const Key('navigation-rail'));
        expect(rail, findsNothing);
        expect(find.byType(InkoraWordmark), findsNothing);
        final header = find.byType(InkScreenHeader);
        if (wide) {
          expect(header, findsNothing);
          expect(find.byType(BackButton), findsNothing);
        } else if (router.routeInformationProvider.value.uri.path !=
            '/settings') {
          expect(header, findsOneWidget);
          expect(
            find.descendant(of: header, matching: find.byType(BackButton)),
            findsOneWidget,
          );
        }
      }

      checkShellHeader();
      await tester.tap(find.byKey(const ValueKey('settings-category-quality')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/quality',
      );
      checkShellHeader();
      // The sidebar names the page; no in-page title repeats it.
      expect(find.text('Image quality'), findsOneWidget);
      final editor = tester.state<ReaderSettingsSheetState>(
        find.byType(ReaderSettingsSheet),
      );
      final sampler = find.byKey(
        const Key('reader-choice-quality-all-sampling-nearest'),
      );
      await tester.ensureVisible(sampler);
      await tester.tap(sampler);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final reset = find.byKey(const Key('reader-settings-reset'));
      for (final keyboardHeight in [300.0, 450.0, 500.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
        expect(find.text('Save'), findsNothing);
        expect(reset.hitTestable(), findsOneWidget);
      }
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      for (final viewport in [
        const Size(800, 1200),
        const Size(999, 700),
        const Size(1000, 700),
        const Size(1200, 800),
      ]) {
        size(tester, viewport);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
        checkShellHeader();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/settings/quality',
        );
        expect(tester.widget<ChoiceChip>(sampler).selected, isTrue);
        expect(
          find.byKey(const Key('settings-sidebar')),
          viewport.width >= 1000 && viewport.width > viewport.height
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      final account = harness.container
          .read(sessionProvider)
          .session!
          .accountId;
      final saved = await tester.runAsync(
        () => ReaderStore(
          harness.database,
          account,
        ).overrides(SettingsScope.global, ''),
      );
      expect(
        saved!.imageQuality![RasterFormat.jpeg]!.sampling,
        ImageSampling.nearest,
      );
      await harness.close(tester);
    },
  );

  testWidgets(
    'setup keeps its library draft and footer when rotating and resizing',
    (tester) async {
      size(tester, const Size(1200, 800));
      resetView(tester);
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(locale: 'en', setupStep: 4),
      );
      addTearDown(() => harness.close(tester));
      await tester.runAsync(
        () =>
            UiPreferencesStore(harness.database)
                .update((p) => p.copyWith(setupCompleted: false)),
      );
      await harness.mount(tester);
      expect(find.byKey(const Key('setup-sidebar')), findsOneWidget);
      await tester.tap(find.text('Manga shelf'));
      await tester.pumpAndSettle();
      final editor = tester.state<ReaderSettingsSheetState>(
        find.byType(ReaderSettingsSheet),
      );
      final mode = find.byKey(const Key('reader-choice-mode-webtoon'));
      await tester.ensureVisible(mode);
      await tester.tap(mode);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      for (final viewport in [
        const Size(800, 1200),
        const Size(650, 700),
        const Size(1200, 800),
      ]) {
        size(tester, viewport);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
        expect(tester.widget<ChoiceChip>(mode).selected, isTrue);
        expect(
          find.byKey(const Key('setup-back')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('setup-next')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSettingsSheet), findsNothing);
      final account = harness.container
          .read(sessionProvider)
          .session!
          .accountId;
      final saved = await tester.runAsync(
        () => ReaderStore(
          harness.database,
          account,
        ).overrides(SettingsScope.library, 'library-a'),
      );
      expect(saved!.mode, ReadingMode.webtoon);
      await harness.close(tester);
    },
  );

  for (final language in languageNames.keys) {
    testWidgets(
      '$language landscape categories, appearance groups and setup fit at normal and large text',
      (tester) async {
        size(tester, const Size(1200, 800));
        resetView(tester);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: language),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        final light = find.byKey(const Key('light-theme-group'));
        final dark = find.byKey(const Key('dark-theme-group'));
        final coverCounts = find.byKey(const Key('home-portrait-columns'));
        await tester.ensureVisible(coverCounts);
        await tester.pumpAndSettle();
        // The rail fits its longest localized word (the square test font
        // widens it), so pair the groups whenever the pane keeps 720px.
        final pane = tester.getTopRight(dark).dx - tester.getTopLeft(light).dx;
        if (pane >= 720) {
          expect(
            tester.getTopLeft(dark).dx,
            greaterThan(tester.getTopRight(light).dx),
          );
        } else {
          expect(
            tester.getTopLeft(dark).dy,
            greaterThan(tester.getBottomLeft(light).dy),
          );
        }
        expect(find.byKey(const Key('navigation-rail')), findsNothing);
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        size(tester, const Size(320, 640));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('theme-midnight')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(dark).dy,
          greaterThan(tester.getBottomLeft(light).dy),
        );
        expect(tester.takeException(), isNull);
        size(tester, const Size(1200, 800));
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => UiPreferencesStore(harness.database)
              .update((p) => p.copyWith(setupStep: 2, setupCompleted: false)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('setup-sidebar')), findsOneWidget);
        expect(
          find.byKey(const Key('setup-next')).hitTestable(),
          findsOneWidget,
        );
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('setup-sidebar')), findsNothing);
        expect(
          find.byKey(const Key('setup-next')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
