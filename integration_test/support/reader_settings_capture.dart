import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

void registerSettingsCaptures() {
  testWidgets('native French reader modal visual checkpoints', (tester) async {
    final binding = tester.binding as LiveTestWidgetsFlutterBinding;
    final policy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    addTearDown(() => binding.framePolicy = policy);
    final db = AppDatabase(NativeDatabase.memory());
    final store = ReaderStore(db, 'visual-reader-fixture');
    addTearDown(db.close);
    for (final kind in ['manga', 'comics', 'epub', 'webtoon', 'pdf']) {
      final doc = kind == 'epub' || kind == 'pdf';
      await store.saveOverrides(
        SettingsScope.global,
        '',
        ReadingOverrides(
          mode: doc ? ReadingMode.ebook : ReadingMode.values.byName(kind),
        ),
      );
      final manifest = ReaderManifest(
        accountId: store.accountId,
        bookId: kind,
        revision: 'r1',
        title: 'Visual fixture',
        libraryId: 'library',
        seriesId: 'series',
        documentType: doc
            ? (kind == 'epub' ? 'application/epub+zip' : 'application/pdf')
            : null,
        pages: [PageDimensions(768, 1152)],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: InkoraTheme.ocean(),
          locale: const Locale('fr'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open fixture'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReaderSettingsSheet(
                    store: store,
                    manifest: manifest,
                    modal: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open fixture'));
      await tester.pumpAndSettle();
      // Native SQLite completion uses real I/O, then the controls become active.
      for (
        var i = 0;
        i < 50 && tester.any(find.byType(LinearProgressIndicator));
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final panels = kind == 'epub'
          ? ['Apparence', 'Mise en page', 'Navigation', 'Templates']
          : kind == 'webtoon'
          ? ['Disposition', 'Préchargement']
          : kind == 'manga'
          ? ['Disposition', 'Rendu']
          : ['Disposition'];
      for (final label in panels) {
        if (tester.any(find.byType(Tab))) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('reader-settings-menu')).hitTestable(),
          findsOneWidget,
        );
        debugPrint('SETTINGS_CAPTURE_READY: $kind-$label');
        if (const bool.fromEnvironment('SETTINGS_NATIVE_CAPTURE')) {
          await tester.pump(const Duration(seconds: 6));
        }
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
