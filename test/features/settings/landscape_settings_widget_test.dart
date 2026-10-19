import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
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
    'tablet settings retain the wordmark without header back while editors survive resize',
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
      void checkShellHeader() {
        final header = find.ancestor(
          of: find.byType(InkoraWordmark),
          matching: find.byType(InkAppBar),
        );
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.byType(InkoraWordmark)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.byType(BackButton)),
          findsNothing,
        );
        expect(
          find.descendant(of: header, matching: find.text('Quality')),
          findsNothing,
        );
      }

      checkShellHeader();
      await tester.tap(find.byKey(const ValueKey('settings-category-quality')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/quality',
      );
      checkShellHeader();
      expect(find.text('Quality'), findsOneWidget); // Sidebar category only.
      final editor = tester.state<ReaderSettingsSheetState>(
        find.byType(ReaderSettingsSheet),
      );
      final sampler = find.byType(DropdownButtonFormField<ImageSampling>).first;
      await tester.ensureVisible(sampler);
      await tester.tap(sampler);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nearest neighbour').last);
      await tester.pumpAndSettle();
      for (final keyboardHeight in [300.0, 450.0, 500.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
        expect(find.text('Save').hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text('Save')).dy,
          lessThanOrEqualTo(800 - keyboardHeight),
        );
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
        expect(
          tester
              .widget<DropdownButtonFormField<ImageSampling>>(sampler)
              .initialValue,
          ImageSampling.nearest,
        );
        expect(
          find.byKey(const Key('settings-sidebar')),
          viewport.width >= 1000 && viewport.width > viewport.height
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
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
      final mode = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Mode',
      );
      await tester.ensureVisible(mode);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Webtoon').last);
      await tester.pumpAndSettle();
      for (final viewport in [
        const Size(800, 1200),
        const Size(650, 700),
        const Size(1200, 800),
      ]) {
        size(tester, viewport);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
        expect(
          tester.widget<DropdownButtonFormField<String>>(mode).initialValue,
          'webtoon',
        );
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
        final opacity = find.byKey(const Key('panel-opacity'));
        await tester.ensureVisible(opacity);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(dark).dx,
          greaterThan(tester.getTopRight(light).dx),
        );
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
