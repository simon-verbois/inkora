import '../../support/reader_preferences.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/app/widgets/ink_snap_sheet.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_fakes.dart';
import '../../support/onboarding_visuals.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final (size, scale, locale) in [
    (const Size(390, 844), 1.0, 'en'),
    (const Size(1024, 768), 1.0, 'en'),
    (const Size(320, 640), 2.0, 'en'),
    for (final locale in languageNames.keys.where((code) => code != 'en'))
      (const Size(320, 640), 2.0, locale),
    (const Size(390, 844), 1.0, 'fr'),
    (const Size(844, 390), 1.0, 'fr'),
  ]) {
    testWidgets(
      'library apply button saves edited values and replaces book tuning at $size/$scale/$locale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final store = ReaderStore(database, 'reader-account');
        final manifest = readerManifest();
        await tester.runAsync(() async {
          await store.saveManifest(manifest);
          await store.saveOverrides(
            SettingsScope.book,
            manifest.bookId,
            const ReadingOverrides(mode: ReadingMode.manga),
          );
        });
        final strings = AppStrings(locale);
        const capture = Key('library-apply-capture');
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.dark(amoled: true),
            locale: AppStrings.localeFor(locale),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => RepaintBoundary(
              key: capture,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReaderSettingsSheet(
                        store: store,
                        libraryId: 'library',
                        showScope: false,
                      ),
                    ),
                    child: const Text('Preferences'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Preferences'));
        await tester.pumpAndSettle();
        await chooseReaderPreference(tester, 'reader-choice-mode-webtoon');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Direction')), findsNothing);
        expect(find.text(strings.text('Page layout')), findsOneWidget);
        expect(find.text(strings.text('Comfortable width')), findsOneWidget);
        final apply = find.byKey(const Key('apply-library-defaults'));
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        const explanation =
            'Apply these preferences to every series and book in this library, replacing their custom reading preferences.';
        expect(find.text(strings.text(explanation)), findsNothing);
        await tester.tap(apply);
        // A second quick tap cannot open another replacement confirmation.
        await tester.tap(apply, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(InkSnapSheet), findsOneWidget);
        expect(find.text(strings.text(explanation)), findsOneWidget);
        expect(
          find.text(strings.text('Apply to all series and books?')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const Key('library-apply-cancel')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('library-apply-cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(InkSnapSheet), findsNothing);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, manifest.bookId),
          ))!.mode,
          ReadingMode.manga,
        );
        await tester.tap(apply);
        await tester.pumpAndSettle();
        await tester.drag(
          find.text(strings.text(explanation)),
          const Offset(0, 650),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InkSnapSheet), findsNothing);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, manifest.bookId),
          ))!.mode,
          ReadingMode.manga,
        );
        await tester.tap(apply);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(InkSnapSheet), findsNothing);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.book, manifest.bookId),
          ))!.mode,
          ReadingMode.manga,
        );
        await tester.tap(apply);
        await tester.pumpAndSettle();
        final confirm = find.byKey(const Key('library-apply-confirm'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await captureOnboarding(
          tester,
          find.byKey(capture),
          'library-apply-$locale-${size.width.toInt()}-${scale.toInt()}',
        );
        expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
        await tester.tap(confirm);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        final settings = await tester.runAsync(
          () => store.settings(manifest).first,
        );
        expect(settings!.mode, ReadingMode.webtoon);
        expect(settings.fit, ReadingFit.comfort);
        expect(find.byType(ReaderSettingsSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
