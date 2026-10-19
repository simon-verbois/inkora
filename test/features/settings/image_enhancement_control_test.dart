import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';
import 'package:inkora/core/images/image_enhancement.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/presentation/image_enhancement_control.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final locale in AppStrings.supportedLocales) {
      testWidgets('quality separates upscaling at $size / $locale / 200%', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale.languageCode),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        harness.container.read(routerProvider).go('/settings/quality');
        await tester.pumpAndSettle();
        expect(find.byType(ImageEnhancementControl), findsNothing);
        final strings = AppStrings(locale.languageCode);
        final tab = find.widgetWithText(Tab, strings.text('Upscaling'));
        await tester.ensureVisible(tab);
        await tester.pumpAndSettle();
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.byType(ImageEnhancementControl), findsOneWidget);
        expect(find.text(strings.text('JPEG / JPG')), findsNothing);
        expect(find.text(strings.text('Save')), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ImageEnhancementControl),
            matching: find.byType(InkSurface),
          ),
          findsNothing,
        );
        final rendering = find.widgetWithText(Tab, strings.text('Rendering'));
        await tester.ensureVisible(rendering);
        await tester.pumpAndSettle();
        await tester.tap(rendering);
        await tester.pumpAndSettle();
        expect(find.byType(ImageEnhancementControl), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }
  testWidgets('settings groups and category rows have no panel surfaces', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    for (final section in [
      'appearance',
      'accessibility',
      'transfer',
      'about',
    ]) {
      router.go('/settings/$section');
      await tester.pumpAndSettle();
      final panels = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(InkPanel),
      );
      expect(panels, findsWidgets);
      expect(
        find.descendant(of: panels, matching: find.byType(InkSurface)),
        findsNothing,
      );
    }
    for (final path in ['/settings', '/settings/reading']) {
      router.go(path);
      await tester.pumpAndSettle();
      final rows = find.byType(InkSettingsRow);
      expect(rows, findsWidgets);
      expect(
        find.descendant(of: rows, matching: find.byType(InkSurface)),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
  for (final width in [320.0, 1024.0]) {
    testWidgets(
      'image strength persists with complete localized controls at $width and 200%',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        for (final locale in AppStrings.supportedLocales) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.container,
              child: MaterialApp(
                locale: locale,
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: const [
                  AppStrings.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      child: ImageEnhancementControl(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final strings = AppStrings(locale.languageCode);
          expect(
            find.text(strings.text('Upscaling and sharpening')),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byType(DropdownButtonFormField<ImageEnhancement>),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byType(DropdownButtonFormField<ImageEnhancement>),
          );
          await tester.pumpAndSettle();
          final next =
              harness.container
                      .read(uiPreferencesProvider)
                      .asData
                      ?.value
                      .imageEnhancement ==
                  ImageEnhancement.strong
              ? ImageEnhancement.off
              : ImageEnhancement.strong;
          await tester.tap(
            find
                .text(
                  strings.text(
                    next == ImageEnhancement.strong ? 'Strong' : 'Off',
                  ),
                )
                .last,
          );
          await tester.runAsync(() async {
            final store = await harness.container.read(
              uiPreferencesStoreProvider,
            );
            await store.watch().firstWhere(
              (value) => value.imageEnhancement == next,
            );
          });
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButtonFormField<ImageEnhancement>>(
                  find.byType(DropdownButtonFormField<ImageEnhancement>),
                )
                .initialValue,
            next,
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
