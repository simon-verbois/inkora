import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/images/image_enhancement.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/presentation/image_enhancement_control.dart';

import '../../support/ui_harness.dart';

void main() {
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
