import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';
import 'package:inkora/offline/presentation/download_settings_panel.dart';

import '../../support/ui_harness.dart';

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
          preferences: UiPreferences(locale: language, setupStep: 4),
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

        void checkWrapper() {
          expect(router.routeInformationProvider.value.uri.path, '/setup');
          expect(find.text(strings.text('Make Inkora yours')), findsOneWidget);
          expect(find.byKey(const Key('navigation-settings')), findsNothing);
          expect(tester.widget(back), isA<OutlinedButton>());
          expect(tester.widget(next), isA<FilledButton>());
          expect(tester.getSize(back), tester.getSize(next));
          expect(tester.getTopLeft(back).dy, tester.getTopLeft(next).dy);
          final left = tester.getRect(back);
          final right = tester.getRect(next);
          expect((left.left + right.right) / 2, closeTo(size.width / 2, 1));
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
        checkWrapper();
        expect(find.byType(ReaderSettingsSheet), findsOneWidget);
        final mode = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == strings.text('Mode'),
        );
        await tester.ensureVisible(mode);
        await tester.pumpAndSettle();
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Webtoon').last);
        await tester.pumpAndSettle();
        await tester.tap(next);
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
          4,
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
        expect(find.byType(DownloadSettingsPanel), findsOneWidget);
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
    expect(tester.widget<OutlinedButton>(back).onPressed, isNull);
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
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Inkora'), findsOneWidget);
    final ebookIntroduction = find.text(
      'Read EPUB and PDF books with adjustable text, bookmarks and synchronized progress.',
    );
    await tester.scrollUntilVisible(
      ebookIntroduction,
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(ebookIntroduction, findsOneWidget);
    expect(find.byType(ReaderSettingsSheet), findsNothing);
    for (var step = 1; step < 7; step++) {
      expect(find.text('Keep current reading settings'), findsNothing);
      expect(find.text('All saved progress is synchronized.'), findsNothing);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('Ready to read'), findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
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
