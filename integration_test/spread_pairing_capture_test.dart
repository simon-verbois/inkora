import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../test/support/reader_fakes.dart';
import '../test/reader/presentation/paged_profiles_test.dart' as profiles;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture and persist automatic/manual manga pairing', (
    tester,
  ) async {
    final tablet =
        tester.view.physicalSize.shortestSide / tester.view.devicePixelRatio >=
        600;
    final prefix = tablet ? 'tablet' : 'phone';
    await SystemChrome.setPreferredOrientations([
      tablet ? DeviceOrientation.landscapeLeft : DeviceOrientation.portraitUp,
    ]);
    final database = AppDatabase(NativeDatabase.memory());
    final store = ReaderStore(database, 'reader-account');
    final manifest = readerManifest();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await SystemChrome.setPreferredOrientations([]);
    });
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
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: InkoraTheme.ocean(),
        locale: const Locale('fr'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: ReaderSettingsSheet(store: store, manifest: manifest),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    for (final mode in [
      SpreadPairing.automatic,
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
      await tester.pumpAndSettle();
      expect(tester.widget<RadioListTile<String>>(choice).selected, true);
      final settings = await store.settings(manifest).first;
      expect(settings.spreadPairing, mode);
      expect(settings.spreadOffset, mode == SpreadPairing.shifted);
      await binding.takeScreenshot('$prefix-pairing-${mode.name}');
    }
    expect(tester.takeException(), isNull);
  });
  profiles.main();
}
