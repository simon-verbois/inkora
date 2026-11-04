import '../../support/reader_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';
import 'package:inkora/offline/presentation/download_settings_panel.dart';
import 'package:inkora/features/settings/presentation/setup_introduction.dart';

import '../../support/ui_harness.dart';
import '../../support/onboarding_visuals.dart' show chooseSetupMode;

void main() {
  for (final (size, scale, language) in [
    (const Size(390, 844), 1.0, 'fr'),
    (const Size(1024, 768), 1.0, 'de'),
    (const Size(320, 640), 2.0, 'hu'),
  ]) {
    testWidgets(
      'setup owns library editing and its footer at $size/$language',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: language, setupStep: 3),
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((current) => current.copyWith(setupCompleted: false)),
        );
        await harness.mount(tester, textScale: scale);
        final router = harness.container.read(routerProvider);
        final strings = AppStrings(language);
        final back = find.byKey(const Key('setup-back'));
        final next = find.byKey(const Key('setup-next'));
        Future<void> revealLibrary() async {
          await tester.scrollUntilVisible(
            find.text('Manga shelf'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
        }

        void checkWrapper({bool library = false}) {
          expect(router.routeInformationProvider.value.uri.path, '/setup');
          if (library) {
            final localBack = find.byKey(const Key('setup-library-back'));
            expect(localBack, findsOneWidget);
            expect(tester.widget(localBack), isA<BackButton>());
            expect(find.byType(CloseButton), findsNothing);
            expect(
              find.byKey(const Key('apply-library-defaults')),
              findsNothing,
            );
            expect(
              find.text(
                strings.text(
                  'Apply these preferences to every series and book in this library, replacing their custom reading preferences.',
                ),
              ),
              findsNothing,
            );
            final title = find.byKey(const Key('setup-library-title'));
            expect(
              find.descendant(
                of: find.byType(InkScreenHeader),
                matching: title,
              ),
              findsOneWidget,
            );
            expect(
              tester.getTopLeft(title).dx,
              closeTo(tester.getTopRight(localBack).dx + 16, 1),
            );
            expect(
              tester.getCenter(title).dy,
              closeTo(tester.getCenter(localBack).dy, 1),
            );
            expect(
              find.descendant(
                of: find.byType(InkScreenHeader),
                matching: find.text(strings.text('Back')),
              ),
              findsNothing,
            );
            expect(back, findsNothing);
            expect(next, findsNothing);
            return;
          }
          expect(find.text(strings.text('Make Inkora yours')), findsOneWidget);
          expect(find.byKey(const Key('open-settings')), findsNothing);
          expect(tester.widget(back), isA<OutlinedButton>());
          expect(tester.widget(next), isA<FilledButton>());
          expect(tester.getSize(back), tester.getSize(next));
          expect(tester.getTopLeft(back).dy, tester.getTopLeft(next).dy);
          final left = tester.getRect(back);
          final right = tester.getRect(next);
          if (size.width >= 1000 && size.width > size.height && scale <= 1.3) {
            expect(right.right, closeTo(size.width - 24, 1));
          } else {
            expect((left.left + right.right) / 2, closeTo(size.width / 2, 1));
          }
          expect(
            find.descendant(
              of: back,
              matching: find.text(strings.text('Back')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: next,
              matching: find.text(strings.text('Next')),
            ),
            findsOneWidget,
          );
        }

        checkWrapper();
        await revealLibrary();
        await tester.tap(find.text('Manga shelf'));
        await tester.pumpAndSettle();
        checkWrapper(library: true);
        expect(find.byType(ReaderSettingsSheet), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(find.byKey(const Key('reader-settings-scope')), findsNothing);
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
        final layoutHelp = find.text(
          strings.text('Two pages in landscape windows and on tablets.'),
        );
        final pairing = find.byKey(
          const ValueKey(('reader-choice-spreadPairing', 'automatic')),
        );
        expect(layoutHelp, findsOneWidget);
        expect(
          tester.getTopLeft(pairing).dy - tester.getBottomLeft(layoutHelp).dy,
          greaterThanOrEqualTo(20),
        );

        await chooseSetupMode(tester, 'webtoon');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('setup-library-back')));
        await tester.pumpAndSettle();
        checkWrapper();
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
        expect(
          (await tester.runAsync(
            () => UiPreferencesStore(harness.database).watch().first,
          ))!.setupStep,
          3,
        );

        // System back cancels a library draft inside the wrapper.
        await revealLibrary();
        await tester.tap(find.text('Manga shelf'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        checkWrapper();
        expect(find.byType(ReaderSettingsSheet), findsNothing);
        await tester.tap(next);
        await tester.pumpAndSettle();
        checkWrapper();
        expect(find.text(strings.text('Browse libraries')), findsNothing);
        expect(find.byType(ReaderSettingsSheet), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        expect(find.byKey(const Key('reader-settings-scope')), findsNothing);
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);

        expect(
          find.text(strings.text('Upscaling and sharpening')),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(Tab, strings.text('Upscaling')),
          findsNothing,
        );
        expect(find.byType(TabBar), findsNothing);
        expect(find.text(strings.text('Save')), findsNothing);
        await chooseReaderPreference(
          tester,
          'reader-choice-quality-all-sampling-nearest',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        checkWrapper();
        expect(find.byType(DownloadSettingsPanel), findsOneWidget);
        final quality = await tester.runAsync(
          () => ReaderStore(
            harness.database,
            account,
          ).overrides(SettingsScope.global, ''),
        );
        expect(
          quality!.imageQuality![RasterFormat.jpeg]!.sampling,
          ImageSampling.nearest,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets('setup introduces features and only exits after its final Next', (
    tester,
  ) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(locale: 'en'),
    );
    addTearDown(() => harness.close(tester));
    await tester.runAsync(
      () =>
          UiPreferencesStore(harness.database)
              .update((current) => current.copyWith(setupCompleted: false)),
    );
    await harness.mount(tester);
    final next = find.byKey(const Key('setup-next'));
    final back = find.byKey(const Key('setup-back'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      harness.container
          .read(routerProvider)
          .routeInformationProvider
          .value
          .uri
          .path,
      '/setup',
    );
    expect(find.byType(SetupIntroduction), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byKey(const Key('setup-introduction-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(next, 180, scrollable: scrollable);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(back).onPressed, isNull);
    expect(find.descendant(of: scrollable, matching: next), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsNothing);
    expect(find.text('Application theme'), findsOneWidget);
    for (var step = 1; step < 7; step++) {
      expect(find.text('Language'), findsNothing);
      expect(find.byType(SetupIntroduction), findsNothing);
      expect(find.text('Reset to default'), findsNothing);
      expect(find.byKey(const Key('hide-tags')), findsNothing);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('Start reading').hitTestable(), findsOneWidget);
    expect(find.byType(SetupIntroduction), findsNothing);
    expect(find.text('Reset to default'), findsNothing);
    expect(find.text('Finish setup'), findsNothing);
    expect(
      (await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      ))!.setupCompleted,
      false,
    );
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
      (await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      ))!.setupCompleted,
      true,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
