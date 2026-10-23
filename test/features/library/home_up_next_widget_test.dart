import '../../support/home_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets('Home resume and history without Up next at $size/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reading = entry(
        'book-reading',
        title: 'Solo.Leveling.T03.FR',
        seriesId: 'series-a',
        number: 3,
      );
      final next = entry(
        'book-next',
        title: 'Atlas.Nine.T02.FR',
        seriesId: 'series-b',
        number: 2,
      );
      final harness = await UiHarness.create(
        tester,
        resumeEntries: [
          ResumeEntry(
            item: reading,
            seriesTitle: 'Solo Leveling',
            pageIndex: 9,
            pageCount: 20,
            fraction: 0,
          ),
          ResumeEntry(
            item: next,
            seriesTitle: 'Atlas Nine',
            pageIndex: 0,
            pageCount: 20,
            fraction: 0,
            pageKnown: false,
            onDeck: true,
          ),
        ],
        catalogue: [
          entry('library-a', kind: CatalogueKind.library),
          entry('series-a', kind: CatalogueKind.series, title: 'Solo Leveling'),
          entry('series-b', kind: CatalogueKind.series, title: 'Atlas Nine'),
          reading,
          next,
        ],
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester, textScale: scale);
      final router = harness.container.read(routerProvider);

      // Continue reading: series title + shared progress label; the On Deck
      // volume moved to its own Up next shelf.
      final resume = find.byType(ResumeCarousel);
      final upNext = find.byType(UpNextShelf);
      expect(resume, findsOneWidget);
      expect(upNext, findsNothing);
      expect(
        find.descendant(of: resume, matching: find.text('Solo Leveling')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resume,
          matching: find.text('Solo.Leveling.T03.FR · 45 %'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: resume, matching: find.text('Atlas Nine')),
        findsNothing,
      );
      // No raw file names anywhere on Home.
      expect(find.textContaining('Solo.Leveling.T03.FR'), findsOneWidget);

      // View all opens the reading history; Back returns Home.
      await tapHomeAction(tester, 'history');
      await tester.pumpAndSettle();
      expect(find.byType(ReadingHistoryScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');

      // Continue reading cards still open the book directly.
      final resumeCard = find.byKey(const ValueKey('resume-book-reading'));
      await tester.ensureVisible(resumeCard);
      await tester.pumpAndSettle();
      await tester.tap(resumeCard);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
        'book-reading',
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }
}
