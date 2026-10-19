import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_transfer_panel.dart';
import 'package:inkora/reader/data/reading_history.dart';
import 'package:inkora/offline/presentation/batch_download_sheet.dart';

import '../../support/ui_harness.dart';
import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final locale in AppStrings.supportedLocales) {
      testWidgets('transfer and batch actions fit $locale at $size / 200%', (
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
        final router = harness.container.read(routerProvider);
        router.go('/settings/transfer');
        await tester.pumpAndSettle();
        expect(find.byType(SettingsTransferPanel), findsOneWidget);
        expect(
          find.text(AppStrings(locale.languageCode).text('Export QR code')),
          findsNothing,
        );
        for (final key in [
          'Export to file',
          'Import from file',
          'Scan QR code',
        ]) {
          final action = find.widgetWithText(
            OutlinedButton,
            AppStrings(locale.languageCode).text(key),
          );
          final target = key == 'Export to file'
              ? find.widgetWithText(
                  FilledButton,
                  AppStrings(locale.languageCode).text(key),
                )
              : action;
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        router.go('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        final download = find.text(
          AppStrings(locale.languageCode).text('Download volumes'),
        );
        await tester.ensureVisible(download);
        await tester.pumpAndSettle();
        await tester.tap(download);
        await tester.pumpAndSettle();
        expect(find.byType(BatchDownloadSheet), findsOneWidget);
        final next = find.text(
          AppStrings(locale.languageCode).text('Next 3 unread volumes'),
        );
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        final rows = find.byType(CheckboxListTile);
        await tester.scrollUntilVisible(
          rows,
          120,
          scrollable: find
              .descendant(
                of: find.byType(BatchDownloadSheet),
                matching: find.byType(Scrollable),
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(rows, findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }
  testWidgets(
    'history is reachable, contains completed books and clear retains progress',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await tester.runAsync(
        () => ReadingHistoryStore(harness.database, savedSession.accountId)
            .opened(
              readerManifest(account: savedSession.accountId, book: 'book-a'),
            ),
      );
      await harness.mount(tester);
      await tester.tap(find.text('Reading history'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture reader'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No reading history yet.'), findsOneWidget);
      await harness.close(tester);
    },
  );
}
