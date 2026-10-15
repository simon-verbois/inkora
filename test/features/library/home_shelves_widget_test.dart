import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/library_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'Home trailing View all cards and ten-item carousels at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final books = List.generate(
          14,
          (i) => entry(
            'book-$i',
            title: 'Volume ${i.toString().padLeft(3, '0')}',
            seriesId: 'series-$i',
          ),
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
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(() async {
          await harness.repository.store.stage('home-shelves', [
            entry('library-a', kind: CatalogueKind.library),
            ...books,
            for (var i = 0; i < 44; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ]);
          await harness.repository.store.publish(
            'home-shelves',
            DateTime.utc(2026, 10, 12),
            () => true,
          );
        });
        await harness.mount(tester, textScale: scale);
        final home = find.byType(LibraryScreen);
        expect(
          find.descendant(of: home, matching: find.byIcon(InkIcons.caretRight)),
          findsNothing,
        );
        for (var index = 0; index < 5; index++) {
          final heading = find.text(
            [
              'Continue reading',
              'Discover · Library surprises',
              'Recently updated',
              'From your libraries',
              'More to explore',
            ][index],
          );
          await tester.scrollUntilVisible(
            heading,
            200,
            scrollable: find
                .descendant(of: home, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          final panel = find.ancestor(
            of: heading,
            matching: find.byType(InkPanel),
          );
          final shelf = find.descendant(
            of: panel,
            matching: find.byType(CatalogueShelf),
          );
          final visibleItems = tester
              .widget<CatalogueShelf>(shelf)
              .items
              .take(10)
              .toList();
          final overflowItems = tester
              .widget<CatalogueShelf>(shelf)
              .items
              .skip(10)
              .toList();
          if (index == 1 || index >= 3) {
            expect(
              visibleItems.every(
                (item) => !books.any((book) => book.seriesId == item.id),
              ),
              isTrue,
            );
          }
          final horizontal = find.descendant(
            of: shelf,
            matching: find.byType(Scrollable),
          );
          final horizontalState = tester.state<ScrollableState>(horizontal);
          horizontalState.position.jumpTo(
            horizontalState.position.maxScrollExtent,
          );
          await tester.pumpAndSettle();
          final end = visibleItems.last.title;
          expect(
            find.descendant(of: shelf, matching: find.text(end)),
            findsWidgets,
          );
          for (final excluded in overflowItems) {
            expect(
              find.descendant(of: shelf, matching: find.text(excluded.title)),
              findsNothing,
            );
          }
          // Query limits and the shared carousel both keep end-of-list bounded.
          final list = tester.widget<ListView>(
            find.descendant(of: shelf, matching: find.byType(ListView)),
          );
          expect(list.semanticChildCount, 11);
          final action = find.descendant(
            of: shelf,
            matching: find.text('View all'),
          );
          expect(action, findsOneWidget);
          final actionPoster = find.descendant(
            of: find.ancestor(of: action, matching: find.byType(InkWell)).first,
            matching: find.byType(AspectRatio),
          );
          final lastBook = find.descendant(
            of: shelf,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CatalogueCard &&
                  widget.item.id == visibleItems.last.id,
            ),
          );
          expect(
            tester.getSize(actionPoster).width,
            tester.getSize(lastBook).width,
          );
          expect(
            tester.getSize(actionPoster).height,
            closeTo(tester.getSize(lastBook).width / .7, .01),
          );
          expect(
            tester.getTopLeft(actionPoster).dx,
            greaterThan(tester.getTopRight(lastBook).dx),
          );
        }
        final router = harness.container.read(routerProvider);
        for (final (label, destination) in [
          ('Continue reading', '/libraries'),
          ('Browse all books', '/libraries'),
          ('Browse libraries', '/libraries'),
          ('Explore your libraries', '/libraries'),
          ('Recently updated', '/catalogue/series'),
        ]) {
          router.go('/');
          await tester.pumpAndSettle();
          final button = find.byTooltip(label);
          final vertical = find
              .descendant(of: home, matching: find.byType(Scrollable))
              .first;
          tester.state<ScrollableState>(vertical).position.jumpTo(0);
          await tester.pumpAndSettle();
          final heading = find.text(switch (label) {
            'Continue reading' => 'Continue reading',
            'Browse all books' => 'Discover · Library surprises',
            'Browse libraries' => 'From your libraries',
            'Explore your libraries' => 'More to explore',
            _ => 'Recently updated',
          });
          await tester.scrollUntilVisible(heading, 200, scrollable: vertical);
          await tester.pumpAndSettle();
          final shelf = find.descendant(
            of: find.ancestor(of: heading, matching: find.byType(InkPanel)),
            matching: find.byType(CatalogueShelf),
          );
          final horizontal = find.descendant(
            of: shelf,
            matching: find.byType(Scrollable),
          );
          tester
              .state<ScrollableState>(horizontal)
              .position
              .jumpTo(
                tester
                    .state<ScrollableState>(horizontal)
                    .position
                    .maxScrollExtent,
              );
          await tester.pumpAndSettle();
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: button,
              matching: find.byIcon(InkIcons.squaresFour),
            ),
            findsOneWidget,
          );
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(
            tester.widget<CatalogueScreen>(find.byType(CatalogueScreen)).kind,
            destination == '/catalogue/book'
                ? CatalogueKind.book
                : CatalogueKind.series,
          );
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
