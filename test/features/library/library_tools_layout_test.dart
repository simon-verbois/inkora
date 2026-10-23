import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
      'Home tools remain accessible and pin below header at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: const [],
          catalogue: [
            entry(
              'library-a',
              kind: CatalogueKind.library,
              title: 'First shelf',
            ),
            entry(
              'library-b',
              kind: CatalogueKind.library,
              title: 'Second shelf',
            ),
            for (var i = 0; i < 180; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                libraryId: i.isEven ? 'library-a' : 'library-b',
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        final bar = find.byType(InkFilterBar);
        final tools = find.byKey(const Key('catalogue-pinned-tools'));
        final chips = find.byKey(const Key('catalogue-chips'));
        final menu = find.byKey(const Key('catalogue-tools-menu'));
        final effective = (tester.getSize(bar).width - 24) / scale;
        if (scale <= 1.5) {
          final grid = find.byKey(const Key('catalogue-grid'));
          final padding = tester.widget<CatalogueGrid>(grid).topPadding;
          expect(
            padding,
            size.width >= 840 && size.width > size.height ? 4 : 16,
          );
          final first = find.descendant(
            of: grid,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is InkCoverTile && widget.item.id == 'series-0',
            ),
          );
          expect(
            tester.getTopLeft(first).dy - tester.getBottomLeft(tools).dy,
            closeTo(padding, 1),
          );
        }

        if (effective < 600) {
          expect(menu.hitTestable(), findsOneWidget);
          expect(tester.getCenter(chips).dy, tester.getCenter(menu).dy);
          expect(
            tester.getSize(tools).height,
            tester.getSize(chips).height + 8,
          );
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('catalogue-library-menu')));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('library-choice-all')), findsNothing);
          expect(find.byKey(const Key('home-header')), findsOneWidget);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('catalogue-library-menu')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('library-choice-library-b')));
          await tester.pumpAndSettle();
          expect(find.text('Series 000'), findsNothing);
          expect(find.text('Series 001'), findsOneWidget);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('catalogue-sort-menu')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('catalogue-sort-titleDescending')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Series 179'), findsOneWidget);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('catalogue-menu-view')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('catalogue-list')), findsOneWidget);
        } else if (effective >= InkFilterBar.wideWidth) {
          final selector = find.byKey(const Key('library-selector'));
          expect(
            tester.getBottomLeft(selector).dy - tester.getBottomLeft(chips).dy,
            -10,
          );
          expect(
            tester.getCenter(find.byKey(const Key('catalogue-sort'))).dy,
            tester.getCenter(selector).dy,
          );
        }
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        final header = find.byKey(const Key('home-header'));
        expect(header.hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(tools).dy,
          closeTo(tester.getBottomLeft(header).dy - 8, 1),
        );
        expect(chips.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
