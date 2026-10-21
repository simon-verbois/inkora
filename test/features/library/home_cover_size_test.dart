import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(800, 1280),
    const Size(1280, 900),
  ]) {
    testWidgets(
      'Home grid and resume share the selected cover count at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final books = [
          for (var i = 0; i < 8; i++)
            CatalogueItem(
              kind: CatalogueKind.book,
              id: 'book-$i',
              seriesId: 'series-$i',
              title: 'Book $i',
              pageCount: 30,
            ),
        ];
        final harness = await UiHarness.create(
          tester,
          catalogue: [
            entry('library-a', kind: CatalogueKind.library),
            for (var i = 0; i < 8; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series $i',
              ),
            ...books,
          ],
          resumeEntries: [
            for (var i = 0; i < 8; i++)
              ResumeEntry(
                item: books[i],
                seriesTitle: 'Series $i',
                pageIndex: 5,
                pageCount: 30,
                fraction: 0,
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final store = UiPreferencesStore(harness.database);
        final landscape = size.width > size.height;
        for (final count in landscape ? [5, 6, 7] : [2, 3, 4]) {
          await tester.runAsync(
            () => store.update(
              (p) => landscape
                  ? p.copyWith(homeLandscapeColumns: count)
                  : p.copyWith(homePortraitColumns: count),
            ),
          );
          await tester.pumpAndSettle();
          final grid = find.byKey(const Key('catalogue-grid'));
          final covers = find.descendant(
            of: grid,
            matching: find.byType(BookCover),
          );
          final shelfCover = find
              .descendant(
                of: find.byType(ResumeCarousel),
                matching: find.byType(BookCover),
              )
              .first;
          final shelfWidth = tester.getSize(shelfCover).width;
          for (
            var attempt = 0;
            covers.evaluate().isEmpty && attempt < 5;
            attempt++
          ) {
            await tester.drag(
              find.byType(CustomScrollView).first,
              const Offset(0, -150),
            );
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(covers.first);
          await tester.pumpAndSettle();
          final gridWidget = tester.widget<SliverGrid>(
            find.descendant(of: grid, matching: find.byType(SliverGrid)),
          );
          expect(
            (gridWidget.gridDelegate
                    as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            count,
          );
          final top = tester.getTopLeft(covers.first).dy;
          for (var i = 1; i < count; i++) {
            expect(tester.getTopLeft(covers.at(i)).dy, top);
          }
          expect(shelfWidth, closeTo(tester.getSize(covers.first).width, .01));
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(CustomScrollView).first,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position;
          position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        // Rotation/window resizing selects the independently saved other count.
        tester.view.physicalSize = landscape
            ? const Size(390, 844)
            : const Size(1280, 900);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CatalogueGrid>(find.byKey(const Key('catalogue-grid')))
              .columns,
          landscape ? 3 : 6,
        );
        await harness.close(tester);
      },
    );
  }

  testWidgets(
    'Home cover choices do not resize or rebuild secondary catalogue grids',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester, resumeEntries: const []);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      final store = UiPreferencesStore(harness.database);
      for (final path in [
        '/catalogue/series',
        '/catalogue/library/library-a',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        final grid = find.byType(CatalogueGrid).last;
        final before = tester.widget<CatalogueGrid>(grid);
        final cover = find
            .descendant(of: grid, matching: find.byType(BookCover))
            .first;
        final width = tester.getSize(cover).width;
        await tester.runAsync(
          () => store.update(
            (p) => p.copyWith(homePortraitColumns: 2, homeLandscapeColumns: 5),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<CatalogueGrid>(grid), same(before));
        expect(tester.widget<CatalogueGrid>(grid).columns, isNull);
        expect(tester.getSize(cover).width, width);
      }
      await harness.close(tester);
    },
  );
}
