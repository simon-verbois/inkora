import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/onboarding_visuals.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final locale in AppStrings.supportedLocales) {
    for (final (size, scale) in [
      (const Size(320, 640), 2.0),
      (const Size(1024, 768), 1.0),
    ]) {
      testWidgets(
        'setup mode dropdown selects and persists every profile at $locale/$size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          final store = ReaderStore(database, 'dropdown-account');
          await tester.runAsync(
            () => store.saveOverrides(
              SettingsScope.library,
              'library',
              const ReadingOverrides(mode: ReadingMode.comics),
            ),
          );
          final editorKey = GlobalKey<ReaderSettingsSheetState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: InkoraTheme.dark(),
              locale: locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ReaderSettingsSheet(
                  key: editorKey,
                  store: store,
                  libraryId: 'library',
                  sectioned: true,
                  showScope: false,
                  showReset: false,
                  onSaved: () {},
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          final selector = find.byKey(const Key('reader-mode-selector'));
          expect(find.byType(TabBar), findsNothing);
          for (final mode in ReadingMode.values) {
            expect(
              find.byKey(Key('reader-choice-mode-${mode.name}')),
              findsNothing,
            );
            await chooseSetupMode(tester, mode.name);
            await tester.runAsync(
              () => editorKey.currentState!.savePreferences(),
            );
            await tester.pumpAndSettle();
            expect(
              tester.state<FormFieldState<ReadingMode>>(selector).value,
              mode,
            );
            final saved = await tester.runAsync(
              () => store.overrides(SettingsScope.library, 'library'),
            );
            expect(saved!.mode, mode);
            expect(find.byType(TabBar), findsNothing);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
