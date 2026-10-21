import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'single library scroll keeps bounded resume above catalogue at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final books = List.generate(
          14,
          (i) => entry('book-$i', title: 'Volume $i', seriesId: 'series-$i'),
        );
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [
            for (final book in books)
              ResumeEntry(
                item: book,
                seriesTitle: book.title,
                pageIndex: 1,
                pageCount: 20,
                fraction: 0,
              ),
          ],
          catalogue: [
            entry('library-a', kind: CatalogueKind.library),
            ...books,
            for (var i = 0; i < 120; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(ResumeCarousel), findsOneWidget);
        expect(find.text('Continue reading'), findsOneWidget);
        final carousel = find.descendant(
          of: find.byType(ResumeCarousel),
          matching: find.byType(ListView),
        );
        final list = tester.widget<ListView>(carousel);
        expect(
          list.childrenDelegate.estimatedChildCount,
          19,
        ); // 10 covers + separators; no trailing View all card.
        expect(
          find.byKey(const ValueKey('shelf-view-all-Reading history')),
          findsNothing,
        );
        await tester.ensureVisible(find.byType(ResumeCarousel));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reading-history-action')));
        await tester.pumpAndSettle();
        expect(find.byType(ReadingHistoryScreen), findsOneWidget);
        harness.container.read(routerProvider).pop();
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(ResumeCarousel),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(ResumeCarousel)).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('library-selector'))).dy,
          ),
        );
        final router = harness.container.read(routerProvider);
        await tester.tap(find.byKey(const ValueKey('resume-book-0')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
          'book-0',
        );
        router.pop();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scrollable, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key(scale > 1.5 ? 'catalogue-list' : 'catalogue-grid')),
          findsOneWidget,
        );
        expect(
          tester.widgetList<InkCoverTile>(find.byType(InkCoverTile)).length,
          lessThan(40),
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
