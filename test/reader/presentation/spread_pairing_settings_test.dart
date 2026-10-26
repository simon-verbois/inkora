import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/reader_fakes.dart';

void main() {
  for (final locale in AppStrings.supportedLocales) {
    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      testWidgets('pairing modes persist and fit $locale / $size / 200%', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        final store = ReaderStore(database, 'reader-account');
        final manifest = readerManifest();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(database.close);
        });
        await tester.runAsync(() async {
          await store.saveOverrides(
            SettingsScope.global,
            '',
            const ReadingOverrides(mode: ReadingMode.manga),
          );
          await store.saveSpreadAnalysis(
            manifest,
            SpreadPairingAnalysis(
              revision: manifest.revision,
              rightToLeft: true,
              shifted: false,
            ),
          );
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.ocean(),
            locale: locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ReaderSettingsSheet(store: store, manifest: manifest),
            ),
          ),
        );
        Future<void> settle() async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
        }

        await settle();
        for (final mode in SpreadPairing.values) {
          final choice = find.byKey(
            Key('reader-choice-spreadPairing-${mode.name}'),
          );
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(choice.hitTestable(), findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: choice, matching: find.byType(RichText)).first,
          );
          expect(paragraph.didExceedMaxLines, false);
          expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
        }
        for (final mode in [
          SpreadPairing.shifted,
          SpreadPairing.unshifted,
          SpreadPairing.automatic,
        ]) {
          final choice = find.byKey(
            Key('reader-choice-spreadPairing-${mode.name}'),
          );
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          await tester.tap(choice);
          await settle();
          expect(tester.widget<RadioListTile<String>>(choice).selected, true);
          final settings = await tester.runAsync(
            () => store.settings(manifest).first,
          );
          expect(settings!.spreadPairing, mode);
          expect(settings.spreadOffset, mode == SpreadPairing.shifted);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
