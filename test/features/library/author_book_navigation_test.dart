import '../../app/home_navigation_widget_test.dart' show backEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/book_detail_screen.dart';
import 'package:inkora/features/library/presentation/series_detail_screen.dart';
import 'package:inkora/reader/presentation/configured_reader_screen.dart';

import 'series_detail_widget_test.dart'
    show openSeries, showVolumes, tapVisible;

void main() {
  for (final book in ['v1', 'v4']) {
    testWidgets(
      'phone author book $book stays visible above the retained reader',
      (tester) async {
        final harness = await openSeries(
          tester,
          ebooks: true,
          read: 0,
          current: null,
        );
        final router = harness.container.read(routerProvider);
        router.go('/');
        await tester.pumpAndSettle();
        router.push('/reader/v1');
        await tester.pumpAndSettle();
        final retainedReader = tester.element(
          find.byType(ConfiguredReaderScreen),
        );
        router.push('/reader-parent/series-a?book=v1');
        await tester.pumpAndSettle();
        await showVolumes(tester);
        final row = find.byKey(ValueKey('volume-$book'));
        await tapVisible(
          tester,
          find.descendant(
            of: row,
            matching: find.text(
              'Moonlit District ${book == 'v1' ? '01' : '04'}',
            ),
          ),
        );
        expect(find.byType(BookDetailScreen), findsOneWidget);
        expect(
          tester.widget<BookDetailScreen>(find.byType(BookDetailScreen)).id,
          book,
        );
        expect(
          find.byKey(const Key('book-detail-read')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final started = await backEvent(tester, 'startBackGesture');
        if (started == true) {
          await backEvent(tester, 'updateBackGestureProgress');
          await backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(find.byType(BookDetailScreen), findsOneWidget);
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await backEvent(tester, 'commitBackGesture');
        } else {
          router.pop();
        }
        await tester.pumpAndSettle();
        expect(find.byType(SeriesDetailScreen), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(ConfiguredReaderScreen)),
          same(retainedReader),
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );

    testWidgets(
      'phone author book $book reading retains one reader and Home history',
      (tester) async {
        final harness = await openSeries(
          tester,
          ebooks: true,
          read: 0,
          current: null,
        );
        final router = harness.container.read(routerProvider);
        router.go('/');
        await tester.pumpAndSettle();
        router.push('/reader/v1');
        await tester.pumpAndSettle();
        final retained = tester.element(find.byType(ConfiguredReaderScreen));
        router.push('/reader-parent/series-a?book=v1');
        await tester.pumpAndSettle();
        await showVolumes(tester);
        await tapVisible(
          tester,
          find.descendant(
            of: find.byKey(ValueKey('volume-$book')),
            matching: find.text(
              'Moonlit District ${book == 'v1' ? '01' : '04'}',
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('book-detail-read')));
        await tester.pumpAndSettle();
        final reader = find.byType(ConfiguredReaderScreen);
        expect(tester.widget<ConfiguredReaderScreen>(reader).bookId, book);
        expect(
          find.byType(ConfiguredReaderScreen, skipOffstage: false),
          findsOneWidget,
        );
        if (book == 'v1') expect(tester.element(reader), same(retained));
        expect(find.byType(BookDetailScreen), findsNothing);
        expect(find.byType(SeriesDetailScreen), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
