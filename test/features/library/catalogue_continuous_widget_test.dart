import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  testWidgets(
    'pull to refresh removes retired duplicates and updates metadata',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        catalogue: [
          entry('library-a', kind: CatalogueKind.library),
          entry('old-series', kind: CatalogueKind.series, title: 'Stone'),
          entry('new-series', kind: CatalogueKind.series, title: 'Stone'),
        ],
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      harness.container.read(routerProvider).go('/catalogue/series');
      await tester.pumpAndSettle();
      expect(find.text('Stone'), findsNWidgets(2));
      final remote = harness.repository.remote as FakeCatalogueRemote;
      remote.items[CatalogueKind.series] = [
        entry('new-series', kind: CatalogueKind.series, title: 'Stone revised'),
      ];
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator).last,
      );
      await tester.runAsync(refresh.onRefresh);
      await tester.pumpAndSettle();
      expect(find.text('Stone'), findsNothing);
      expect(find.text('Stone revised'), findsOneWidget);
      // The old identity remains available to historical/offline references.
      final retired = await tester.runAsync(
        () => harness.repository.store
            .item(CatalogueKind.series, 'old-series')
            .first,
      );
      expect(retired!.available, isFalse);
      await tester.tap(find.byKey(const Key('catalogue-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show unavailable items'));
      await tester.tap(find.byKey(const Key('filters-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Stone'), findsOneWidget);
      expect(find.text('Stone revised'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'compact controls and continuous three-column mobile grid at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await tester.runAsync(() async {
          await harness.repository.store.stage('scroll', [
            entry('library-a', kind: CatalogueKind.library),
            for (var i = 0; i < 85; i++)
              entry(
                'book-$i',
                kind: CatalogueKind.series,
                title: 'Volume ${i.toString().padLeft(3, '0')}',
              ),
          ]);
          await harness.repository.store.publish(
            'scroll',
            DateTime.now(),
            () => true,
          );
        });
        await harness.mount(tester);
        harness.container.read(routerProvider).go('/catalogue/series');
        await tester.pumpAndSettle();
        // The local search field is visible, not behind an icon toggle.
        expect(find.byKey(const Key('catalogue-search')), findsOneWidget);
        expect(find.byTooltip('Next page'), findsNothing);
        await tester.tap(find.byKey(const Key('catalogue-filters')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Show unavailable items'),
              )
              .value,
          isFalse,
        );
        await tester.tap(find.byKey(const Key('filters-apply')));
        await tester.pumpAndSettle();
        final covers = find.byType(BookCover);
        final third = tester.getTopLeft(covers.at(2));
        expect(third.dy, tester.getTopLeft(covers.first).dy);
        if (size.width < 600) {
          expect(tester.getTopLeft(covers.at(3)).dy, greaterThan(third.dy));
        }
        final card = find.byType(InkCoverTile).first;
        final title = find.descendant(
          of: card,
          matching: find.text('Volume 000'),
        );
        final count = find.descendant(of: card, matching: find.text('0 books'));
        expect(
          tester.getTopLeft(count).dy - tester.getBottomLeft(title).dy,
          lessThanOrEqualTo(1),
        );
        final scroll = find
            .descendant(
              of: find.byType(CustomScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Volume 080'),
          500,
          scrollable: scroll,
          maxScrolls: 45,
        );
        await tester.pumpAndSettle();
        expect(find.text('Volume 080'), findsOneWidget);
        final feed = harness.container
            .read(
              catalogueFeedProvider(
                const CatalogueQuery(
                  kind: CatalogueKind.series,
                  readingUnits: true,
                  showUnavailable: false,
                ),
              ),
            )
            .requireValue!;
        expect(feed.state.page.items, hasLength(85));
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
