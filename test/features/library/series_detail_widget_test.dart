import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/connection_fakes.dart';
import '../../support/ui_harness.dart';

/// Series with [volumes] numbered volumes: the first [read] are read and
/// volume [current] (1-based) is in progress at zero-based page 10.
Future<void> seedSeries(
  UiHarness harness,
  WidgetTester tester, {
  int volumes = 6,
  int read = 2,
  int? current = 3,
  String status = 'ONGOING',
  bool ebooks = false,
  int summaryRepeats = 14,
}) => tester.runAsync(() async {
  await harness.repository.store.stage('series-page', [
    const CatalogueItem(
      kind: CatalogueKind.library,
      id: 'library-a',
      title: 'Manga shelf',
    ),
    CatalogueItem(
      kind: CatalogueKind.series,
      id: 'series-a',
      title: 'Moonlit District',
      libraryId: 'library-a',
      itemCount: volumes,
      summary: List.filled(
        summaryRepeats,
        'Lanterns, alleys and quiet detectives under a pale moon.',
      ).join(' '),
      metadata: CatalogueMetadata(
        status: status,
        publisher: 'Fixture Press',
        genres: const ['Mystery', 'Drama'],
        authors: const [
          CatalogueAuthor('Writer Name', 'writer'),
          CatalogueAuthor('Artist Name', 'penciller'),
        ],
        releaseDate: '2019-04-01',
        language: 'en',
      ),
    ),
    for (var i = 1; i <= volumes; i++)
      CatalogueItem(
        kind: CatalogueKind.book,
        id: 'v$i',
        title: 'Moonlit District ${i.toString().padLeft(2, '0')}',
        seriesId: 'series-a',
        libraryId: 'library-a',
        number: i.toDouble(),
        pageCount: ebooks ? 0 : 30,
        metadata: CatalogueMetadata(
          mediaType: ebooks ? 'application/epub+zip' : '',
        ),
        readingStatus: i <= read
            ? ReadingStatus.completed
            : i == current
            ? ReadingStatus.inProgress
            : ReadingStatus.unread,
        readPage: i == current ? 10 : (i <= read ? 29 : null),
        readModified: i <= read || i == current ? 'v$i-server' : null,
      ),
  ]);
  await harness.repository.store.publish(
    'series-page',
    DateTime.now(),
    () => true,
  );
});

Future<UiHarness> openSeries(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  int volumes = 6,
  int read = 2,
  int? current = 3,
  String status = 'ONGOING',
  bool ebooks = false,
  int summaryRepeats = 14,
  List<ResumeEntry> resumeEntries = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = await UiHarness.create(
    tester,
    preferences: const UiPreferences(locale: 'en'),
    resumeEntries: resumeEntries,
    refreshCatalogue: false,
  );
  addTearDown(() => harness.close(tester));
  await seedSeries(
    harness,
    tester,
    volumes: volumes,
    read: read,
    current: current,
    status: status,
    ebooks: ebooks,
    summaryRepeats: summaryRepeats,
  );
  await harness.mount(tester, textScale: textScale);
  harness.container.read(routerProvider).push('/catalogue/series/series-a');
  await tester.pumpAndSettle();
  return harness;
}

Finder mainScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('series-series-a')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [target] into view below the pinned tab bar (phone layout).
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 160, scrollable: mainScroll());
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final tabs = find.byKey(const Key('series-tabs'));
  if (tabs.evaluate().isEmpty) return;
  final overlap =
      tester.getRect(tabs).bottom - tester.getRect(target.first).top;
  if (overlap > 0) {
    final position = tester.state<ScrollableState>(mainScroll()).position;
    position.jumpTo(position.pixels - overlap - 8);
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> showVolumes(WidgetTester tester) async {
  final tab = find.byKey(const Key('series-tab-volumes'));
  await tester.scrollUntilVisible(tab, 200, scrollable: mainScroll());
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> chooseFilter(WidgetTester tester, String name) async {
  final chip = find.byKey(ValueKey('volume-filter-$name'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder row(String id) => find.byKey(ValueKey('volume-$id'));

void main() {
  Future<List<(String, String, String)>> intents(
    UiHarness harness,
    WidgetTester tester,
  ) async => (await tester.runAsync(
    () => ProgressStore(harness.database, savedSession.accountId).pending(),
  ))!.map((e) => (e.bookId, e.operation.name, e.revision)).toList();

  testWidgets(
    'phone: About is the first and default tab, visible without scrolling below the header',
    (tester) async {
      final harness = await openSeries(tester);
      final tabs = find.byKey(const Key('series-tabs'));
      expect(tabs, findsOneWidget);
      final about = find.byKey(const Key('series-tab-about'));
      final volumes = find.byKey(const Key('series-tab-volumes'));
      expect(
        tester.getTopLeft(about).dx,
        lessThan(tester.getTopLeft(volumes).dx),
      );
      expect(find.text('Volumes (6)'), findsOneWidget);
      expect(tester.getBottomLeft(tabs).dy, lessThanOrEqualTo(844));
      expect(find.byKey(const Key('series-about')), findsOneWidget);
      expect(find.byType(VolumeRow), findsNothing);
      // Header content starts below the floating bubble band.
      final band = tester.getBottomLeft(
        find.byKey(const Key('floating-header-back')),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('series-title'))).dy,
        greaterThan(band.dy),
      );
      // Identity chips: volume count, status (always) and publisher.
      expect(find.text('6 volumes'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('series-status')),
          matching: find.text('Ongoing'),
        ),
        findsOneWidget,
      );
      expect(find.text('Fixture Press'), findsWidgets);
      // The primary action has no series progress card above it.
      expect(
        find.text('Moonlit District 03 · Page 11/30 · 33 %'),
        findsNothing,
      );
      expect(find.byKey(const Key('series-progress')), findsNothing);
      expect(find.byKey(const Key('series-segments')), findsNothing);
      expect(find.text('2/6 read'), findsNothing);
      expect(find.text('Continue - Moonlit District 03'), findsOneWidget);
      // Publication facts with localized roles and server names.
      await tester.scrollUntilVisible(
        find.text('Writer'),
        200,
        scrollable: mainScroll(),
      );
      expect(find.text('Writer Name'), findsOneWidget);
      expect(find.text('Release date'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  for (final status in ['ENDED', 'HIATUS', '']) {
    testWidgets('status chip is always shown ($status)', (tester) async {
      final harness = await openSeries(tester, status: status);
      expect(
        find.descendant(
          of: find.byKey(const Key('series-status')),
          matching: find.text(switch (status) {
            'ENDED' => 'Ended',
            'HIATUS' => 'Hiatus',
            _ => 'Status unknown',
          }),
        ),
        findsOneWidget,
      );
      await harness.close(tester);
    });
  }

  testWidgets('server resume uses the book title without number or page', (
    tester,
  ) async {
    final harness = await openSeries(
      tester,
      resumeEntries: const [
        ResumeEntry(
          item: CatalogueItem(
            kind: CatalogueKind.book,
            id: 'v3',
            title: 'The Lantern Mystery',
            seriesId: 'series-a',
            number: 3,
            pageCount: 30,
          ),
          seriesTitle: 'Moonlit District',
          pageIndex: 10,
          pageCount: 30,
          fraction: 0,
        ),
      ],
    );
    expect(find.text('Continue - The Lantern Mystery'), findsOneWidget);
    expect(find.textContaining('Vol. 03'), findsNothing);
    await harness.close(tester);
  });

  testWidgets('scrolling keeps the tabs pinned below the band', (tester) async {
    final harness = await openSeries(tester, volumes: 30);
    await showVolumes(tester);
    final band = tester
        .getBottomLeft(find.byKey(const Key('floating-header-back')))
        .dy;
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    final tabs = tester.getRect(find.byKey(const Key('series-tabs')));
    expect(tabs.top, greaterThanOrEqualTo(band));
    expect(tabs.top, lessThan(band + InkFloatingHeader.barExtent));
    expect(find.byKey(const Key('floating-header-title')), findsOneWidget);
    await harness.close(tester);
  });

  testWidgets(
    'volumes default to a list with status rows; the grid is optional',
    (tester) async {
      final harness = await openSeries(tester);
      await showVolumes(tester);
      expect(find.byType(VolumeRow), findsWidgets);
      expect(find.byType(VolumeTile), findsNothing);
      expect(
        find.descendant(of: row('v1'), matching: find.text('30 pages · Read')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('v3'),
          matching: find.text('30 pages · In progress · 33 %'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('volume-progress-v3')), findsOneWidget);
      expect(
        find.descendant(
          of: row('v4'),
          matching: find.text('30 pages · Unread'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('volume-view')));
      await tester.pumpAndSettle();
      expect(find.byType(VolumeTile), findsWidgets);
      expect(find.byType(VolumeRow), findsNothing);
      expect(find.byKey(const ValueKey('volume-read-v1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('volume-view')));
      await tester.pumpAndSettle();
      expect(find.byType(VolumeRow), findsWidgets);
      // Tapping a row opens the reader.
      await tapVisible(tester, row('v4'));
      expect(
        tester.widget<ReaderScreen>(find.byType(ReaderScreen)).bookId,
        'v4',
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets('filters and reverse order', (tester) async {
    final harness = await openSeries(tester);
    await showVolumes(tester);
    await chooseFilter(tester, 'unread');
    expect(row('v1'), findsNothing);
    expect(row('v3'), findsNothing);
    expect(row('v4'), findsOneWidget);
    await chooseFilter(tester, 'inProgress');
    expect(find.byType(VolumeRow), findsOneWidget);
    expect(row('v3'), findsOneWidget);
    await chooseFilter(tester, 'downloaded');
    expect(find.text('No volumes match this filter.'), findsOneWidget);
    await chooseFilter(tester, 'all');
    final first = tester.getTopLeft(row('v1')).dy;
    expect(first, lessThan(tester.getTopLeft(row('v2')).dy));
    await tester.tap(find.byKey(const Key('volume-order')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(row('v6')).dy,
      lessThan(tester.getTopLeft(row('v5')).dy),
    );
    await harness.close(tester);
  });

  testWidgets('jump to current volume in a long series', (tester) async {
    final harness = await openSeries(
      tester,
      volumes: 74,
      read: 40,
      current: 41,
    );
    await showVolumes(tester);
    expect(row('v41'), findsNothing);
    expect(find.byKey(const Key('series-segments')), findsNothing);
    final jump = find.byKey(const Key('volume-jump'));
    expect(
      find.descendant(
        of: jump,
        matching: find.text('Jump to current volume · Moonlit District 41'),
      ),
      findsOneWidget,
    );
    await tester.tap(jump);
    await tester.pumpAndSettle();
    final target = tester.getRect(row('v41'));
    final tabs = tester.getRect(find.byKey(const Key('series-tabs')));
    expect(target.top, greaterThanOrEqualTo(tabs.bottom - 1));
    expect(target.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'multi-select marks read and unread through the outbox with batch confirmation',
    (tester) async {
      final harness = await openSeries(tester);
      await showVolumes(tester);
      await tester.tap(find.byKey(const Key('volume-select')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selection-bar')), findsOneWidget);
      await tapVisible(tester, row('v4'));
      await tapVisible(tester, row('v5'));
      expect(find.text('Selected: 2 volumes'), findsOneWidget);
      await tester.tap(find.byKey(const Key('selection-read')));
      await tester.pumpAndSettle();
      expect(find.text('Mark as read?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(await intents(harness, tester), isEmpty);
      await tester.tap(find.byKey(const Key('selection-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ink-confirm-accept')));
      await tester.pumpAndSettle();
      expect(await intents(harness, tester), [
        ('v4', 'complete', ProgressIntent.anyRevision),
        ('v5', 'complete', ProgressIntent.anyRevision),
      ]);
      // Optimistic: the rows show the local state before any upload.
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row('v4'), matching: find.text('30 pages · Read')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('selection-bar')), findsNothing);
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        4,
      );
      expect(
        tester
            .widget<BookCover>(
              find.descendant(of: row('v4'), matching: find.byType(BookCover)),
            )
            .muted,
        isTrue,
      );
      // A single selected volume needs no confirmation.
      await tester.tap(find.byKey(const Key('volume-select')));
      await tester.pumpAndSettle();
      await tapVisible(tester, row('v1'));
      expect(
        tester
            .widget<BookCover>(
              find.descendant(of: row('v1'), matching: find.byType(BookCover)),
            )
            .muted,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('selection-unread')));
      await tester.pumpAndSettle();
      expect(find.text('Mark as unread?'), findsNothing);
      expect((await intents(harness, tester)).first, (
        'v1',
        'markUnread',
        ProgressIntent.anyRevision,
      ));
      expect(
        tester
            .widget<BookCover>(
              find.descendant(of: row('v1'), matching: find.byType(BookCover)),
            )
            .muted,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets('mark previous volumes as read from the row menu', (
    tester,
  ) async {
    final harness = await openSeries(tester, read: 1, current: null);
    await showVolumes(tester);
    await reveal(tester, row('v4'));
    await tester.longPress(row('v4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark previous volumes as read'));
    await tester.pumpAndSettle();
    expect(find.text('Mark previous volumes as read?'), findsOneWidget);
    expect(
      find.textContaining('Unread volumes before this one: 2 volumes.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ink-confirm-accept')));
    await tester.pumpAndSettle();
    expect((await intents(harness, tester)).map((e) => e.$1), ['v2', 'v3']);
    expect(
      harness.container
          .read(seriesProgressProvider('series-a'))
          .requireValue
          .readCount,
      3,
    );
    await harness.close(tester);
  });

  testWidgets(
    'series download confirms every book without entering selection',
    (tester) async {
      final harness = await openSeries(tester);
      await tester.tap(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selection-bar')), findsNothing);
      expect(find.text('Download volumes?'), findsOneWidget);
      expect(
        find.text(
          'Selection: 6 books. The volumes are added to the download queue.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selection-bar')), findsNothing);
      await harness.close(tester);
    },
  );

  testWidgets('ebook series counts books and downloads zero-page originals', (
    tester,
  ) async {
    final harness = await openSeries(
      tester,
      ebooks: true,
      read: 0,
      current: null,
    );
    expect(find.text('6 books'), findsOneWidget);
    expect(find.text('6 volumes'), findsNothing);
    await tester.tap(find.byKey(const Key('detail-download')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Selection: 6 books. The volumes are added to the download queue.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ink-confirm-accept')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
    await tester.pumpAndSettle();
    await harness.close(tester);
  });

  testWidgets(
    'series status action confirms all read and cancellation preserves progress',
    (tester) async {
      final harness = await openSeries(tester);
      await tester.tap(find.byKey(const Key('detail-mark')));
      await tester.pumpAndSettle();
      expect(find.text('Mark read'), findsOneWidget);
      expect(find.text('Mark unread'), findsOneWidget);
      await tester.tap(find.text('Mark read'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as read?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ink-confirm-accept')));
      await tester.pumpAndSettle();
      expect((await intents(harness, tester)).length, 4);
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        6,
      );
      await tester.tap(find.byKey(const Key('detail-mark')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark unread'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as unread?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(seriesProgressProvider('series-a'))
            .requireValue
            .readCount,
        6,
      );
      expect((await intents(harness, tester)).length, 4);
      await harness.close(tester);
    },
  );

  testWidgets(
    'scroll frames rebuild no rows; a progress change rebuilds only its row',
    (tester) async {
      final harness = await openSeries(tester, volumes: 30);
      await showVolumes(tester);
      final rebuilt = <Key?>[];
      final previous = debugOnRebuildDirtyWidget;
      // Elements that exist now; later first builds of rows entering the
      // cache extent are not rebuilds.
      final existing = find.byType(VolumeRow).evaluate().toSet();
      debugOnRebuildDirtyWidget = (element, _) {
        if (existing.contains(element)) rebuilt.add(element.widget.key);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final position = tester.state<ScrollableState>(mainScroll()).position;
      for (var i = 0; i < 5; i++) {
        position.jumpTo(position.pixels + 3);
        await tester.pump();
      }
      expect(rebuilt, isEmpty);
      final before = tester.widget(row('v5'));
      await tester.runAsync(
        () => ProgressStore(
          harness.database,
          savedSession.accountId,
        ).mark([const ProgressMark(bookId: 'v4', pageCount: 30)], read: true),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(rebuilt.toSet(), {const ValueKey('volume-v4')});
      // The cached sliver was reused: other rows keep their widget.
      expect(tester.widget(row('v5')), same(before));
      expect(
        find.descendant(of: row('v4'), matching: find.text('30 pages · Read')),
        findsOneWidget,
      );
      debugOnRebuildDirtyWidget = previous;
      await harness.close(tester);
    },
  );

  testWidgets('genre chip opens the catalogue filtered by that genre', (
    tester,
  ) async {
    final harness = await openSeries(tester);
    await tapVisible(tester, find.byKey(const ValueKey('genre-Mystery')));
    final screen = tester.widget<CatalogueScreen>(find.byType(CatalogueScreen));
    expect(screen.kind, CatalogueKind.series);
    expect(screen.initialFilters.values[CatalogueFacet.genres], 'Mystery');
    await harness.close(tester);
  });

  for (final size in [const Size(1280, 800), const Size(1366, 1024)]) {
    testWidgets(
      'collapsing a visible tablet synopsis preserves the pane offset at $size',
      (tester) async {
        final harness = await openSeries(tester, size: size, summaryRepeats: 6);
        final synopsis = find.byType(SeriesSynopsis);
        final toggle = find.byKey(const Key('detail-summary-toggle'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final pane = find.byKey(const Key('series-about-pane'));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: pane, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final before = position.pixels;
        final top = tester.getTopLeft(synopsis).dy;
        expect(top, greaterThanOrEqualTo(tester.getTopLeft(pane).dy));
        expect(toggle.hitTestable(), findsOneWidget);
        final volumes = tester.getTopLeft(row('v1'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Read more'), findsOneWidget);
        expect(position.pixels, before);
        expect(tester.getTopLeft(synopsis).dy, top);
        expect(tester.getTopLeft(row('v1')), volumes);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets('synopsis collapses with Read more', (tester) async {
    final harness = await openSeries(tester);
    final toggle = find.byKey(const Key('detail-summary-toggle'));
    await tester.ensureVisible(toggle);
    expect(find.text('Read more'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    await harness.close(tester);
  });

  for (final size in [const Size(1280, 800), const Size(1366, 1024)]) {
    testWidgets('wide window: two panes without tabs at $size', (tester) async {
      final harness = await openSeries(tester, size: size, volumes: 30);
      expect(find.byKey(const Key('series-tabs')), findsNothing);
      expect(find.byKey(const Key('series-about-pane')), findsOneWidget);
      expect(find.byKey(const Key('series-progress')), findsNothing);
      expect(find.byKey(const Key('series-segments')), findsNothing);
      expect(find.byKey(const Key('series-volumes-pane')), findsOneWidget);
      expect(find.byKey(const Key('series-volumes-heading')), findsNothing);
      expect(find.text('Volumes (30)'), findsNothing);
      // About content and volumes are visible together.
      expect(find.byType(SeriesAbout), findsOneWidget);
      expect(row('v1'), findsOneWidget);
      // A single column in the volume pane.
      expect(
        tester.getTopLeft(row('v1')).dy,
        lessThan(tester.getTopLeft(row('v2')).dy),
      );
      expect(tester.getTopLeft(row('v1')).dx, tester.getTopLeft(row('v2')).dx);
      // Hero content clears Back; the volume toolbar starts at the pane top.
      final band = tester
          .getBottomLeft(find.byKey(const Key('floating-header-back')))
          .dy;
      expect(
        tester.getTopLeft(find.byKey(const Key('series-title'))).dy,
        greaterThan(band),
      );
      expect(
        tester.getTopLeft(find.byType(VolumeToolbar)).dy,
        tester.getTopLeft(find.byKey(const Key('series-volumes-pane'))).dy,
      );
      // Scrolling the volume pane does not move the About pane.
      final title = tester.getTopLeft(find.byKey(const Key('series-title')));
      final toolbar = tester.getRect(find.byType(VolumeToolbar));
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('series-volumes-pane')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      await tester.drag(
        find.byKey(const Key('series-volumes-pane')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('series-title'))), title);
      expect(tester.getRect(find.byType(VolumeToolbar)), toolbar);
      expect(position.pixels, greaterThan(0));
      final unread = find.byKey(const ValueKey('volume-filter-unread'));
      expect(unread.hitTestable(), findsOneWidget);
      await tester.tap(unread);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VolumeToolbar>(find.byType(VolumeToolbar))
            .controller
            .filter,
        VolumeFilter.unread,
      );
      // View controls remain accessible after both list and grid scrolling.
      await tester.tap(find.byKey(const Key('volume-view')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('series-volumes-pane')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(VolumeToolbar)), toolbar);
      expect(
        find.byKey(const Key('volume-order')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'tablet jump aligns the current volume below the pinned toolbar at $scale',
      (tester) async {
        final harness = await openSeries(
          tester,
          size: const Size(1280, 800),
          textScale: scale,
          volumes: 74,
          read: 40,
          current: 41,
        );
        final pane = find.byKey(const Key('series-volumes-pane'));
        expect(
          find.descendant(of: pane, matching: find.byType(PinnedHeaderSliver)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('volume-jump')));
        await tester.pumpAndSettle();
        final target = tester.getRect(row('v41'));
        final viewport = tester.getRect(pane);
        final toolbarBottom = tester
            .getBottomLeft(find.byType(VolumeToolbar))
            .dy;
        expect(target.top, greaterThanOrEqualTo(toolbarBottom));
        expect(target.top, lessThanOrEqualTo(toolbarBottom + 16));
        expect(target.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets(
    'portrait tablet keeps tabs and shows a single-column volume list',
    (tester) async {
      final harness = await openSeries(
        tester,
        size: const Size(800, 1280),
        volumes: 8,
      );
      expect(find.byKey(const Key('series-tabs')), findsOneWidget);
      await showVolumes(tester);
      expect(
        tester.getTopLeft(row('v1')).dy,
        lessThan(tester.getTopLeft(row('v2')).dy),
      );
      final firstCover = find.descendant(
        of: row('v1'),
        matching: find.byType(BookCover),
      );
      expect(tester.getSize(firstCover).width, 48);
      expect(
        tester
            .getRect(row('v1'))
            .contains(tester.getRect(firstCover).bottomRight),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('200% text keeps the page usable at $size', (tester) async {
      final harness = await openSeries(tester, size: size, textScale: 2);
      expect(find.byKey(const Key('detail-read')), findsOneWidget);
      await showVolumes(tester);
      expect(find.byType(VolumeRow), findsWidgets);
      await tester.tap(find.byKey(const Key('volume-view')));
      await tester.pumpAndSettle();
      expect(find.byType(VolumeTile), findsWidgets);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets('French labels', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(locale: 'fr'),
      resumeEntries: const [],
      refreshCatalogue: false,
    );
    addTearDown(() => harness.close(tester));
    await seedSeries(harness, tester);
    await harness.mount(tester);
    harness.container.read(routerProvider).push('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    expect(find.text('6 tomes'), findsOneWidget);
    expect(find.text('À propos'), findsOneWidget);
    expect(find.text('Tomes (6)'), findsOneWidget);
    expect(find.text('Reprendre - Moonlit District 03'), findsOneWidget);
    expect(find.text('2/6 lus'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
