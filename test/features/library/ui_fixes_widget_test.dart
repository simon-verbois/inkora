import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/offline/data/download_retention_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/presentation/download_book_action.dart';

import '../../support/ui_harness.dart';
import 'series_detail_widget_test.dart' show openSeries, showVolumes;

Future<List<String>?> intentBooks(UiHarness harness, WidgetTester tester) =>
    tester.runAsync(
      () async => [
        for (final intent in await ProgressStore(
          harness.repository.store.database,
          harness.repository.store.accountId,
        ).pending())
          intent.bookId,
      ],
    );

void main() {
  testWidgets(
    'portrait tablet selector is icon-only and quick volume filters start at the left',
    (tester) async {
      final harness = await openSeries(tester, size: const Size(800, 1280));
      await showVolumes(tester);
      final chips = find.byKey(const Key('volume-chips'));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('volume-filter-all'))).dx,
        tester.getTopLeft(chips).dx,
      );
      harness.container.read(routerProvider).go('/');
      await tester.pumpAndSettle();
      final selector = find.byKey(const Key('library-selector'));
      expect(tester.getSize(selector).width, 48);
      expect(
        find.descendant(of: selector, matching: find.byType(Text)),
        findsNothing,
      );
      await harness.close(tester);
    },
  );

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'row completion is direct for unread, guarded for in-progress at $size',
      (tester) async {
        final harness = await openSeries(tester, size: size);
        if (size.width < 840) await showVolumes(tester);
        final row = find.byWidgetPredicate(
          (w) => w is VolumeRow && w.volume.id == 'v3',
        );
        final mark = find.byKey(const ValueKey('volume-mark-read-v3'));
        await tester.ensureVisible(mark);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(mark).right,
          lessThanOrEqualTo(
            tester
                .getRect(
                  find.descendant(
                    of: row,
                    matching: find.byType(DownloadBookAction),
                  ),
                )
                .left,
          ),
        );
        await tester.tap(mark);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.textContaining('replaces its current reading position'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(await intentBooks(harness, tester), isEmpty);
        await tester.tap(mark);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ink-confirm-accept')));
        await tester.pumpAndSettle();
        expect(await intentBooks(harness, tester), ['v3']);
        final unread = find.byKey(const ValueKey('volume-mark-read-v4'));
        await tester.ensureVisible(unread);
        await tester.pumpAndSettle();
        await tester.tap(unread);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(await intentBooks(harness, tester), ['v3', 'v4']);
        await harness.close(tester);
      },
    );

    testWidgets(
      'series download scope includes ongoing books and policy commits only on accept at $size',
      (tester) async {
        final harness = await openSeries(tester, size: size);
        final retention = DownloadRetentionStore(
          harness.repository.store.database,
          harness.repository.store.accountId,
        );
        Future<void> open() async {
          await tester.tap(find.byKey(const Key('detail-download')));
          await tester.pumpAndSettle();
        }

        await open();
        await tester.tap(find.byKey(const Key('download-series-unread')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Selection: 4 books. The volumes are added to the download queue.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('download-series-retention')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(() => retention.enabled('series-a')),
          isFalse,
        );
        await open();
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('download-series-retention')),
              )
              .value,
          isFalse,
        );
        await tester.tap(find.byKey(const Key('download-series-retention')));
        await tester.tap(find.byKey(const Key('ink-confirm-accept')));
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(() => retention.enabled('series-a')),
          isTrue,
        );
        await open();
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('download-series-retention')),
              )
              .value,
          isTrue,
        );
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        await harness.close(tester);
      },
    );

    testWidgets('synopsis and reading action adapt at $size', (tester) async {
      final harness = await openSeries(
        tester,
        size: size,
        read: 0,
        current: null,
      );
      expect(find.text('Start - Moonlit District 01'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('series-synopsis'))).maxLines,
        size.width < size.height
            ? SeriesSynopsis.portraitLines
            : SeriesSynopsis.lines,
      );
      await tester.tap(find.byKey(const Key('detail-mark')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final dialog = tester.getRect(find.byType(Dialog));
      expect(dialog.center.dy, closeTo(size.height / 2, 1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await harness.close(tester);
    });
  }

  for (final locale in AppStrings.supportedLocales) {
    testWidgets('download choices remain reachable in $locale at 320px/200%', (
      tester,
    ) async {
      final harness = await openSeries(
        tester,
        size: const Size(320, 640),
        textScale: 2,
        locale: locale.languageCode,
      );
      await tester.ensureVisible(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final toggle = find.descendant(
        of: find.byKey(const Key('download-series-retention')),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(toggle.hitTestable(), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('download-series-retention')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      await harness.close(tester);
    });
  }

  testWidgets(
    'compact Home menus keep destinations and catalogue tools accessible',
    (tester) async {
      final harness = await openSeries(
        tester,
        size: const Size(320, 640),
        textScale: 2,
      );
      final router = harness.container.read(routerProvider);
      router.go('/');
      await tester.pumpAndSettle();
      final selector = find.byKey(const Key('catalogue-tools-menu'));
      expect(tester.getSize(selector).width, 48);
      await tester.tap(find.byKey(const Key('home-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/downloads');
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );
}
