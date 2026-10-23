import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/book_detail_screen.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/presentation/downloads_screen.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../app/home_navigation_widget_test.dart' show backEvent;
import '../../support/ui_harness.dart';

CatalogueItem _book(String id, {String type = 'application/epub+zip'}) =>
    CatalogueItem(
      kind: CatalogueKind.book,
      id: id,
      title: 'Novel $id',
      libraryId: 'library-a',
      seriesId: 'author',
      metadata: CatalogueMetadata(
        mediaType: type,
        authors: const [CatalogueAuthor('An author', 'writer')],
      ),
    );

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'individual ebooks across Home, library, search and reader at $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            resumeEntries: [
              for (final id in ['a', 'b'])
                ResumeEntry(
                  item: _book(id),
                  seriesTitle: 'An author',
                  pageIndex: 0,
                  pageCount: 0,
                  fraction: 0,
                  raster: false,
                  totalProgression: .25,
                ),
            ],
          );
          addTearDown(() => harness.close(tester));
          final remote = harness.repository.remote as FakeCatalogueRemote;
          remote.items[CatalogueKind.series] = [
            entry('author', kind: CatalogueKind.series, title: 'An author'),
            entry('comics', kind: CatalogueKind.series, title: 'Comic series'),
          ];
          remote.items[CatalogueKind.book] = [
            _book('a'),
            _book('b'),
            _book('c', type: 'application/pdf'),
            entry('comic-volume', seriesId: 'comics'),
          ];
          await tester.runAsync(harness.repository.refresh);
          await harness.mount(tester, textScale: scale);
          final resume = tester.widget<CatalogueShelf>(
            find.descendant(
              of: find.byType(ResumeCarousel),
              matching: find.byType(CatalogueShelf),
            ),
          );
          expect(resume.items.map((item) => item.identity), [
            'book:a',
            'book:b',
          ]);
          expect(find.text('25 %').hitTestable(), findsWidgets);
          await tester.tap(find.byKey(const ValueKey('resume-a')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
            'a',
          );
          expect(find.byType(CatalogueDetailScreen), findsNothing);
          final router = harness.container.read(routerProvider);
          router.pop();
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
          router.go('/');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.descendant(
              of: find.byKey(
                Key(scale > 1.5 ? 'catalogue-list' : 'catalogue-grid'),
              ),
              matching: find.text('Novel a'),
            ),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Novel a'), findsWidgets);
          expect(
            find.text('An author'),
            findsWidgets,
          ); // Credits, never an author card.
          expect(find.byKey(const ValueKey('series:author')), findsNothing);
          final cards = tester.widgetList<InkCoverTile>(
            find.byType(InkCoverTile),
          );
          if (scale == 1) {
            expect(cards.any((card) => card.item.isEbook), isTrue);
            expect(cards.any((card) => card.item.id == 'author'), isFalse);
          }
          router.go('/');
          await tester.pumpAndSettle();
          if (find
              .byKey(const Key('open-search'))
              .hitTestable()
              .evaluate()
              .isNotEmpty) {
            await tester.tap(
              find.byKey(const Key('open-search')).hitTestable().last,
            );
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byKey(const Key('catalogue-search')),
            'Novel c',
          );
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();
          final searchOverlay = find.byWidgetPredicate(
            (widget) =>
                widget.key == const Key('catalogue-grid') ||
                widget.key == const Key('catalogue-list'),
          );
          expect(
            find.descendant(
              of: searchOverlay,
              matching: find.byWidgetPredicate(
                (widget) => widget is Text && widget.data == 'Novel c',
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: searchOverlay, matching: find.text('Novel a')),
            findsNothing,
          );
          await tester.tap(
            find.descendant(of: searchOverlay, matching: find.text('Novel c')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BookDetailScreen), findsOneWidget);
          expect(find.byType(ReaderScreen), findsNothing);
          expect(find.text('Novel c'), findsOneWidget);
          expect(find.text('PDF'), findsNothing);
          expect(find.text('EPUB'), findsNothing);
          expect(
            tester.widget<SeriesBackdrop>(find.byType(SeriesBackdrop)).item.id,
            'c',
          );
          expect(
            tester
                .widget<InkFloatingHeader>(find.byType(InkFloatingHeader))
                .transparentAtRest,
            isTrue,
          );
          if (size.width >= 1000 && scale == 1) {
            final cover = find.byType(BookCover);
            final heading = find.byKey(const Key('book-detail-title'));
            final action = find.byKey(const Key('book-detail-read'));
            expect(cover, findsOneWidget);
            expect(tester.getSize(cover).width, greaterThanOrEqualTo(240));
            expect(
              tester.getRect(cover).right,
              lessThan(tester.getRect(heading).left),
            );
            expect(
              tester.getRect(action).left,
              closeTo(tester.getRect(heading).left, 1),
            );
            expect(
              tester.getRect(action).top,
              greaterThan(tester.getRect(heading).bottom),
            );
          }
          await tester.ensureVisible(find.byKey(const Key('book-detail-read')));
          await tester.tap(find.byKey(const Key('book-detail-read')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
            'c',
          );
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(find.byType(ReaderScreen), findsOneWidget);
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await backEvent(tester, 'commitBackGesture');
          await tester.pumpAndSettle();
          expect(find.byType(BookDetailScreen), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: searchOverlay, matching: find.text('Novel c')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }

    testWidgets(
      'offline ebook root opens directly and confirms removal at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        final store = DownloadStore(
          harness.database,
          'account',
          Directory('/unused'),
        );
        late List<DownloadedSeries> groups;
        await tester.runAsync(() async {
          for (final id in ['a', 'b']) {
            final manifest = ReaderManifest(
              accountId: 'account',
              bookId: id,
              title: 'Novel $id',
              seriesId: 'author',
              revision: '1',
              documentType: 'application/epub+zip',
              pages: [PageDimensions(1, 1)],
            );
            await store.state(
              await store.enqueue(manifest),
              DownloadState.complete,
            );
          }
          groups = await store.completedSeries().first;
        });
        final removed = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => DownloadsScreen(
                onRemoveDownload: (id) async => removed.add(id),
              ),
            ),
            GoRoute(
              name: 'reader',
              path: '/reader/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Reader ${state.pathParameters['id']}')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              coverRepositoryProvider.overrideWith((ref) async => null),
              downloadedReadingSeriesProvider.overrideWith(
                (ref) => Stream.value(groups),
              ),
              downloadsProvider.overrideWith(
                (ref) => Stream.value(
                  groups
                      .expand((group) => group.books.map((book) => book.job))
                      .toList(),
                ),
              ),
              offlineCoordinatorProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Novel a'), findsWidgets);
        expect(find.text('Saved series'), findsNothing);
        await tester.tap(find.text('Novel a'));
        await tester.pumpAndSettle();
        expect(find.text('Reader a'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        // List rows (the default) keep the shared trailing remove action and
        // offer removal in their long-press menu too.
        expect(find.byKey(const ValueKey('volume-download-a')), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        await tester.longPress(
          find.byKey(const ValueKey('download-row-book:a')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Read offline'), findsOneWidget);
        await tester.tap(find.text('Remove download'));
        await tester.pumpAndSettle();
        expect(find.text('Remove this download?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('ink-confirm-accept')));
        await tester.pumpAndSettle();
        expect(removed, [
          groups
              .firstWhere((group) => group.item.id == 'a')
              .books
              .single
              .job
              .id,
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
