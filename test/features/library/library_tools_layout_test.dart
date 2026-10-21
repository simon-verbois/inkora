import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';

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
        final header = find.byKey(const Key('home-header'));
        expect(find.descendant(of: header, matching: history), findsOneWidget);
        expect(tester.widget(history), isA<IconButton>());
        expect(find.text('Reading history'), findsNothing);
        expect(tester.getSize(history), const Size(48, 48));
        expect(find.byTooltip('Search catalogue'), findsNothing);
        final tools = find.byKey(const Key('catalogue-pinned-tools'));
        final selector = find.byKey(const Key('library-selector'));
        final filters = find.byKey(const Key('catalogue-filters'));
        final search = find.byKey(const Key('catalogue-search'));
        final chips = find.byKey(const Key('catalogue-chips'));
        final sort = find.byKey(const Key('catalogue-sort'));
        // Search belongs to the persistent top header; browse tools stay centered.
        expect(
          find.byKey(const Key('reading-quick-filter-menu')),
          findsNothing,
        );
        expect(
          find.descendant(of: sort, matching: find.text('A–Z')),
          size.width >= 600 || scale <= 1.5 ? findsOneWidget : findsNothing,
        );
        expect(tester.getSize(filters).width, greaterThanOrEqualTo(48));
        final wide =
            (tester.getSize(find.byType(InkFilterBar)).width - 24) / scale >=
            InkFilterBar.wideWidth;
        expect(
          tester.getCenter(sort).dy,
          closeTo(tester.getCenter(selector).dy, 2),
        );
        expect(
          tester.getCenter(filters).dy,
          closeTo(tester.getCenter(selector).dy, 2),
        );
        expect(
          tester.getBottomLeft(search).dy,
          lessThanOrEqualTo(tester.getTopLeft(tools).dy),
        );
        if (wide) {
          expect(
            tester.getCenter(chips).dy,
            closeTo(tester.getCenter(selector).dy, 2),
          );
        } else {
          expect(
            tester.getTopLeft(chips).dy,
            greaterThan(tester.getBottomLeft(selector).dy - 1),
          );
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
        // The header/search stay reachable and tools pin below their band.
        expect(
          find.byKey(const Key('home-header')).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(tools).dy,
          closeTo(
            tester.getBottomLeft(find.byKey(const Key('home-header'))).dy,
            1,
          ),
        );
        expect(filters.hitTestable(), findsOneWidget);
        expect(
          find
              .descendant(
                of: search,
                matching: find.byKey(const Key('open-search')),
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(chips.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reading-filter-any')).hitTestable(),
          findsOneWidget,
        );
        // The chip row scrolls rather than wrapping or clipping the toggle.
        final downloaded = find.byKey(
          const ValueKey('reading-filter-downloaded'),
        );
        final chipScroll = tester.state<ScrollableState>(
          find.descendant(of: chips, matching: find.byType(Scrollable)),
        );
        chipScroll.position.jumpTo(chipScroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(downloaded.hitTestable(), findsOneWidget);
        // Changing ordering must retain both the offset and enough loaded rows,
        // including the intermediate asynchronous SQL refresh frames.
        scroll.position.jumpTo(scroll.position.maxScrollExtent * .6);
        await tester.pumpAndSettle();
        final offset = scroll.position.pixels;
        tester
            .widget<InkSortButton<CatalogueSort>>(sort)
            .onSelected(CatalogueSort.titleDescending);
        await tester.pump();
        expect(scroll.position.pixels, closeTo(offset, 1));
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, closeTo(offset, 1));
        expect(
          find.descendant(of: sort, matching: find.text('Z–A')),
          size.width >= 600 || scale <= 1.5 ? findsOneWidget : findsNothing,
        );
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
