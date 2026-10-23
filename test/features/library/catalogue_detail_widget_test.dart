import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/book_detail_screen.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/library/presentation/catalogue_presentation.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

const metadata = CatalogueMetadata(
  status: 'ENDED',
  readingDirection: 'WEBTOON',
  ageRating: 16,
  publisher: 'Fixture Press',
  genres: ['Action', 'Fantasy'],
  tags: [
    'Magic',
    'Adventure',
    'Tag 3',
    'Tag 4',
    'Tag 5',
    'Tag 6',
    'Hidden tag',
  ],
  authors: [
    CatalogueAuthor('Writer Name', 'writer'),
    CatalogueAuthor('Artist Name', 'penciller'),
  ],
  links: [CatalogueLink('Reference', 'https://example.test/reference')],
);
final summary = List.filled(
  12,
  'A long synopsis with portals, hunters and distant worlds.',
).join('\n');

Future<void> seed(
  UiHarness harness,
  WidgetTester tester, {
  int volumes = 2,
  bool document = false,
  bool available = true,
  String? synopsis,
  String? firstVolumeTitle,
}) async {
  await tester.runAsync(() async {
    await harness.repository.store.stage('details', [
      CatalogueItem(
        kind: CatalogueKind.series,
        id: 'series-a',
        title: 'A series with a deliberately long title',
        itemCount: volumes,
        summary: synopsis ?? summary,
        metadata: metadata,
        available: available,
      ),
      for (var i = 0; i < volumes; i++)
        CatalogueItem(
          kind: CatalogueKind.book,
          id: 'volume-$i',
          title: i == 0 && firstVolumeTitle != null
              ? firstVolumeTitle
              : 'Volume ${i.toString().padLeft(3, '0')}',
          seriesId: 'series-a',
          number: i.toDouble(),
          pageCount: document ? 0 : 30,
          summary: i == 0 ? summary : '',
          metadata: i == 0
              ? const CatalogueMetadata(
                  tags: ['Book tag'],
                  authors: [CatalogueAuthor('Volume Author', 'writer')],
                )
              : const CatalogueMetadata(),
        ),
    ]);
    await harness.repository.store.publish(
      'details',
      DateTime.now(),
      () => true,
    );
  });
}

void main() {
  testWidgets(
    'series back bubble survives scrolling and returns to its originating route',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(locale: 'en'),
      );
      addTearDown(() => harness.close(tester));
      await seed(harness, tester, volumes: 30);
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.push('/catalogue/series/series-a');
      await tester.pumpAndSettle();
      final bubble = find.byKey(const Key('floating-header-back'));
      final position = tester.getTopLeft(bubble);
      expect(tester.getSize(bubble).shortestSide, greaterThanOrEqualTo(48));
      final scroll = find.descendant(
        of: find.byType(CatalogueDetailScreen),
        matching: find.byType(CustomScrollView),
      );
      await tester.drag(scroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(bubble), position);
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(CatalogueDetailScreen), findsNothing);
      await harness.close(tester);
    },
  );
  testWidgets('French publication labels preserve server-owned credits', (
    tester,
  ) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(locale: 'fr'),
      resumeEntries: const [],
    );
    addTearDown(() => harness.close(tester));
    await seed(harness, tester);
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('detail-read')),
        matching: find.text('Commencer - Volume 000'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('series-status')),
        matching: find.text('Terminée'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 livres'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Scénariste'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Scénariste'), findsOneWidget);
    expect(find.text('Dessinateur'), findsOneWidget);
    expect(find.text('Writer Name'), findsOneWidget);
    expect(find.text('Artist Name'), findsOneWidget);
    expect(find.text('Fixture Press'), findsWidgets);
    expect(find.text('Hidden tag'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'series metadata, expandable summary and volume rows at $size/$scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            preferences: const UiPreferences(appearance: AppAppearance.light),
            resumeEntries: const [],
          );
          addTearDown(() => harness.close(tester));
          final longSummary = List.filled(5, summary).join('\n');
          const targetTitle =
              'Volume 000 — Les voyageurs des mondes lointains : deuxième partie {0}';
          await seed(
            harness,
            tester,
            volumes: 85,
            synopsis: longSummary,
            firstVolumeTitle: targetTitle,
          );
          await harness.mount(tester, textScale: scale);
          final router = harness.container.read(routerProvider);
          router.go('/catalogue/series/series-a');
          await tester.pumpAndSettle();
          final scrollable = find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first;
          final readButton = find.byKey(const Key('detail-read'));
          final readLabel = find.descendant(
            of: readButton,
            matching: find.text('Start - $targetTitle'),
          );
          expect(readLabel, findsOneWidget);
          final labelBounds = tester.getRect(readLabel);
          final buttonBounds = tester.getRect(readButton);
          expect(labelBounds.left, greaterThanOrEqualTo(buttonBounds.left));
          expect(labelBounds.right, lessThanOrEqualTo(buttonBounds.right));
          expect(find.text('Browse books'), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(const Key('series-status')),
              matching: find.text('Ended'),
            ),
            findsOneWidget,
          );
          expect(find.text('85 books'), findsOneWidget);
          expect(find.text('Webtoon'), findsNothing);
          expect(find.text('16+'), findsNothing);
          {
            final cover = find.descendant(
              of: find.byType(SeriesHero),
              matching: find.byType(BookCover),
            );
            final title = find.byKey(const Key('series-title'));
            expect(tester.getSize(cover).width, lessThanOrEqualTo(180));
            if (scale == 1 && size.width >= 390) {
              expect(
                tester.getTopLeft(title).dx,
                greaterThan(tester.getTopRight(cover).dx),
              );
            }
          }
          final toggle = find.byKey(const Key('detail-summary-toggle'));
          await tester.scrollUntilVisible(toggle, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) => w is SelectableText && w.data == longSummary,
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) => w is SelectableText && w.data == longSummary,
            ),
            findsNothing,
          );
          await tester.scrollUntilVisible(
            find.text('Reference'),
            200,
            scrollable: scrollable,
          );
          expect(find.text('https://example.test/reference'), findsNothing);
          expect(find.text('Status'), findsNothing);
          expect(find.text('Hidden tag'), findsNothing);
          expect(find.text('Writer'), findsOneWidget);
          expect(find.text('Penciller'), findsOneWidget);
          final volumesTab = find.byKey(const Key('series-tab-volumes'));
          if (volumesTab.evaluate().isNotEmpty) {
            await tester.tap(volumesTab);
            await tester.pumpAndSettle();
          }
          final volumeScroll = find
              .descendant(
                of: find.byType(CustomScrollView).last,
                matching: find.byType(Scrollable),
              )
              .first;
          final row = find.byKey(const ValueKey('volume-volume-1'));
          await tester.scrollUntilVisible(row, 120, scrollable: volumeScroll);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: row, matching: find.text('Volume 001')),
            findsOneWidget,
          );
          // Rows show a small cover thumbnail and the download action.
          expect(
            find.descendant(of: row, matching: find.byType(BookCover)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: row,
              matching: find.byTooltip('Download volume'),
            ),
            findsOneWidget,
          );
          final tabs = find.byKey(const Key('series-tabs'));
          if (tabs.evaluate().isNotEmpty &&
              tester.getRect(row).top < tester.getRect(tabs).bottom) {
            final position = tester
                .state<ScrollableState>(volumeScroll)
                .position;
            position.jumpTo(
              position.pixels -
                  (tester.getRect(tabs).bottom - tester.getRect(row).top) -
                  8,
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(
            tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
            'volume-1',
          );
          expect(find.text('Book details'), findsNothing);
          expect(tester.takeException(), isNull);
          router.go('/catalogue/book/volume-0');
          await tester.pumpAndSettle();
          expect(find.byType(BookDetailScreen), findsOneWidget);
          await tester.ensureVisible(find.byKey(const Key('book-detail-read')));
          await tester.tap(find.byKey(const Key('book-detail-read')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
            'volume-0',
          );
          expect(find.text('Book details'), findsNothing);
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }

  testWidgets('all volumes of a long series are listed lazily in sequence', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await seed(harness, tester, volumes: 85);
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    final tab = find.byKey(const Key('series-tab-volumes'));
    if (tab.evaluate().isNotEmpty) {
      await tester.tap(tab);
      await tester.pumpAndSettle();
    }
    // Lazy: far rows are not built before scrolling.
    expect(find.byKey(const ValueKey('volume-volume-80')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('volume-volume-80')),
      500,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 55,
    );
    await tester.pumpAndSettle();
    expect(find.text('Volume 080'), findsOneWidget);
    final volumes = harness.container
        .read(seriesVolumesProvider('series-a'))
        .requireValue;
    expect(volumes.where((v) => v.available), hasLength(85));
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'Home resume opens the ebook directly and returns Home at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [
            const ResumeEntry(
              item: CatalogueItem(
                kind: CatalogueKind.book,
                id: 'volume-1',
                title: 'Volume 001',
                metadata: CatalogueMetadata(mediaType: 'application/epub+zip'),
                seriesId: 'series-a',
              ),
              seriesTitle: 'Ebook series',
              pageIndex: 4,
              pageCount: 30,
              fraction: .2,
              raster: false,
              pageKnown: false,
              totalProgression: .17,
            ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await seed(harness, tester, document: true);
        await harness.mount(tester);
        await tester.tap(find.byKey(const ValueKey('resume-volume-1')));
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueDetailScreen), findsNothing);
        expect(
          tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
          'volume-1',
        );
        expect(find.text('EPUB and local PDF'), findsNothing);
        harness.container.read(routerProvider).pop();
        await tester.pumpAndSettle();
        expect(
          harness.container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  for (final available in [true, false]) {
    testWidgets('direct zero-page volume respects availability $available', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => openCatalogueItem(
                  context,
                  CatalogueItem(
                    kind: CatalogueKind.book,
                    id: 'document',
                    title: 'Document',
                    available: available,
                  ),
                ),
                child: const Text('Open document'),
              ),
            ),
          ),
          GoRoute(
            path: '/read/:id',
            name: 'reader',
            builder: (_, state) =>
                Scaffold(body: Text('Reading ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open document'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reading document'),
        available ? findsOneWidget : findsNothing,
      );
      expect(find.text('EPUB and local PDF'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final onDeck in [false, true]) {
    testWidgets(
      'series reading opens its ${onDeck ? 'On Deck' : 'in-progress'} document through the shared reader route',
      (tester) async {
        final book = const CatalogueItem(
          kind: CatalogueKind.book,
          id: 'volume-1',
          title: 'Volume 001',
          seriesId: 'series-a',
        );
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [
            ResumeEntry(
              item: book,
              pageIndex: 0,
              pageCount: 0,
              fraction: 0,
              raster: false,
              pageKnown: false,
              onDeck: onDeck,
            ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await seed(harness, tester, document: true);
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        expect(
          find.text('${onDeck ? 'Start' : 'Resume'} - Volume 001'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('detail-read')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
          'volume-1',
        );
        expect(find.text('EPUB and local PDF'), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CatalogueDetailScreen>(find.byType(CatalogueDetailScreen))
              .id,
          'series-a',
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  for (final onDeck in [false, true, null]) {
    testWidgets('raster series action opens the correct reader for $onDeck', (
      tester,
    ) async {
      final harness = await UiHarness.create(
        tester,
        resumeEntries: [
          if (onDeck != null)
            ResumeEntry(
              item: const CatalogueItem(
                kind: CatalogueKind.book,
                id: 'volume-1',
                title: 'Volume 001',
                seriesId: 'series-a',
                pageCount: 30,
              ),
              pageIndex: 4,
              pageCount: 30,
              fraction: 0,
              onDeck: onDeck,
            ),
        ],
      );
      addTearDown(() => harness.close(tester));
      await seed(harness, tester);
      final router = GoRouter(
        initialLocation: '/series',
        routes: [
          GoRoute(
            path: '/series',
            builder: (_, _) => const CatalogueDetailScreen(
              kind: CatalogueKind.series,
              id: 'series-a',
            ),
          ),
          GoRoute(
            path: '/catalogue/:kind/:id/read/:bookId',
            name: 'series-reader',
            builder: (_, state) => Scaffold(
              body: Text('Reading ${state.pathParameters['bookId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-read')));
      await tester.pumpAndSettle();
      expect(
        find.text('Reading volume-${onDeck == null ? 0 : 1}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets('unavailable series retains metadata and has no reading action', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await seed(harness, tester, available: false);
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-read')), findsNothing);
    expect(
      find.text('Unavailable or removed. Saved metadata is retained.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
