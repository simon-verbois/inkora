import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_transfer_panel.dart';
import 'package:inkora/reader/data/reading_history.dart';

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
        for (final key in ['Export to file', 'Import from file']) {
          final action = find.widgetWithText(
            OutlinedButton,
            AppStrings(locale.languageCode).text(key),
          );
          final target = action;
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        router.go('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings(locale.languageCode).text('Scan QR code')),
          findsNothing,
        );
        // Whole-series download now opens a confirmation dialog.
        final download = find.byKey(const Key('detail-download'));
        await tester.ensureVisible(download);
        await tester.pumpAndSettle();
        await tester.tap(download);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('selection-bar')), findsNothing);
        expect(
          find.byKey(const Key('ink-confirm-accept')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
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
      await tester.tap(find.byKey(const Key('reading-history-action')));
      await tester.pumpAndSettle();
      // The device open is described from the catalogue: series title, then
      // the volume, its state and the time under Today.
      expect(find.text('Moonlit District'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(
        find.textContaining('Moonlit District · Volume 3 · In progress · '),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear history'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('books with reading progress on Komga stay listed'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Clear history'));
      for (var turn = 0; turn < 5; turn++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('No reading history yet.'), findsOneWidget);
      expect(find.text('Browse catalogue'), findsOneWidget);
      // Nothing left on this device: Clear is disabled.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('history-clear')))
            .onPressed,
        isNull,
      );
      await harness.close(tester);
    },
  );
}
