import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/reading_filter_chips.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(1280, 900), 1.0),
  ]) {
    testWidgets(
      'home title/history and pinned single-row tools at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [
            ResumeEntry(
              item: entry(
                'resume',
                title: 'Current book',
                seriesId: 'series-0',
              ),
              seriesTitle: 'Current series',
              pageIndex: 1,
              pageCount: 20,
              fraction: 0,
            ),
          ],
          catalogue: [
            entry('library-a', kind: CatalogueKind.library),
            for (var i = 0; i < 180; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        final history = find.byKey(const Key('reading-history-action'));
        final title = find.text('Continue reading');
        expect(
          tester.getCenter(history).dy,
          closeTo(tester.getCenter(title).dy, 1),
        );
        expect(find.byTooltip('Search catalogue'), findsNothing);
        final tools = find.byKey(const Key('catalogue-pinned-tools'));
        final selector = find.byKey(const Key('library-selector'));
        final filters = find.byKey(const Key('catalogue-filters'));
        final wide = (size.width - 24) / scale >= 1000;
        if (wide) {
          final chips = find.byKey(const Key('reading-quick-filter-chips'));
          expect(
            tester.getCenter(chips).dx,
            closeTo(tester.getCenter(tools).dx, 1),
          );
          expect(
            find.byKey(const Key('reading-quick-filter-menu')),
            findsNothing,
          );
        } else {
          final popup = find.byKey(const Key('reading-quick-filter-menu'));
          expect(popup.hitTestable(), findsOneWidget);
          expect(tester.getSize(popup).width, greaterThanOrEqualTo(48));
          expect(find.byType(ChoiceChip), findsNothing);
        }
        expect(
          tester.getCenter(selector).dy,
          closeTo(tester.getCenter(filters).dy, 2),
        );
        expect(
          tester.getCenter(find.byType(ReadingFilterChips)).dy,
          closeTo(tester.getCenter(filters).dy, 2),
        );
        if (size.width > 1000) {
          expect(find.text('Completed').hitTestable(), findsOneWidget);
        }
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        final barBottom = tester.getBottomLeft(find.byType(InkAppBar)).dy;
        expect(tester.getTopLeft(tools).dy, closeTo(barBottom, 1));
        expect(filters.hitTestable(), findsOneWidget);
        // Changing ordering must retain both the offset and enough loaded rows,
        // including the intermediate asynchronous SQL refresh frames.
        scroll.position.jumpTo(scroll.position.maxScrollExtent * .6);
        await tester.pumpAndSettle();
        final offset = scroll.position.pixels;
        final sort = tester.widget<PopupMenuButton<CatalogueSort>>(
          find.byKey(const Key('catalogue-sort')),
        );
        sort.onSelected!(CatalogueSort.titleDescending);
        await tester.pump();
        expect(scroll.position.pixels, closeTo(offset, 1));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, closeTo(offset, 1));
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('Series 179'), findsOneWidget);
        await tester.tap(history);
        await tester.pumpAndSettle();
        expect(find.byType(ReadingHistoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
