import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/library/presentation/series_header.dart';

import '../support/catalogue_fakes.dart';
import '../support/ui_harness.dart';

const _phone = Size(390, 844);
const _tabletLandscape = Size(1280, 800);
const _tabletPortrait = Size(800, 1280);

List<CatalogueItem> _catalogue() => [
  entry('library-a', kind: CatalogueKind.library, title: 'Manga shelf'),
  entry('series-a', kind: CatalogueKind.series, title: 'Moonlit District'),
  for (var i = 0; i < 40; i++)
    entry(
      'book-$i',
      title: 'Volume ${i.toString().padLeft(3, '0')}',
      number: i.toDouble(),
    ),
  entry(
    'collection-a',
    kind: CatalogueKind.collection,
    title: 'Favourite shelf',
    members: const ['series-a'],
  ),
  entry(
    'readlist-a',
    kind: CatalogueKind.readlist,
    title: 'Summer list',
    members: const ['book-0'],
  ),
];

Future<UiHarness> _mount(
  WidgetTester tester,
  Size size, {
  double statusBar = 24,
  List<CatalogueItem>? catalogue,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: statusBar, bottom: 16);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  final harness = await UiHarness.create(
    tester,
    resumeEntries: const [],
    catalogue: catalogue ?? _catalogue(),
  );
  addTearDown(() => harness.close(tester));
  await harness.mount(tester);
  return harness;
}

void main() {
  testWidgets('short narrow landscape keeps header controls reachable', (
    tester,
  ) async {
    final harness = await _mount(tester, const Size(320, 240));
    for (final key in [
      'open-settings',
      'open-downloads',
      'reading-history-action',
    ]) {
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('open-search')));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(TextField));
    expect(bounds.width, greaterThanOrEqualTo(48));
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  for (final size in [
    const Size(375, 844),
    const Size(844, 390),
    _tabletPortrait,
    _tabletLandscape,
  ]) {
    testWidgets('header search covers actions and survives rotation $size', (
      tester,
    ) async {
      final harness = await _mount(tester, size);
      final settings = find.byKey(const Key('open-settings'));
      final downloads = find.byKey(const Key('open-downloads'));
      final history = find.byKey(const Key('reading-history-action'));
      final header = find.byKey(const Key('home-header'));
      final headerRect = tester.getRect(header);
      final historyRect = tester.getRect(history);
      expect(settings.hitTestable(), findsOneWidget);
      expect(downloads.hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-search')));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final fieldState = tester.state(field);
      final bounds = tester.getRect(field);
      expect(
        bounds.width,
        size.width > size.height ? greaterThan(280) : equals(280),
      );
      expect(bounds.contains(historyRect.center), true);
      expect(headerRect.contains(bounds.topLeft), true);
      expect(headerRect.contains(bounds.bottomRight), true);
      expect(settings, findsNothing);
      expect(downloads, findsNothing);
      expect(history, findsNothing);
      expect(tester.getRect(header), headerRect);
      await tester.enterText(field, 'Moon');
      await tester.pumpAndSettle();
      final focus = tester.widget<TextField>(field).focusNode!;
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Moon');
      expect(tester.state(field), same(fieldState));
      expect(focus.hasFocus, true);
      expect(settings, findsNothing);
      expect(downloads, findsNothing);
      expect(history, findsNothing);
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.state(field), same(fieldState));
      expect(focus.hasFocus, true);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(settings.hitTestable(), findsOneWidget);
      expect(downloads.hitTestable(), findsOneWidget);
      expect(history.hitTestable(), findsOneWidget);
      expect(tester.getRect(history), historyRect);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  for (final size in [_phone, _tabletLandscape, _tabletPortrait]) {
    final wideSeries = size.width >= 840;
    final wideSettings = size.width >= 1000 && size.width > size.height;

    testWidgets('every shell page has exactly one header level at $size', (
      tester,
    ) async {
      final harness = await _mount(tester, size);
      final router = harness.container.read(routerProvider);
      final wordmarks = find.byType(InkoraWordmark);
      final headers = find.byType(InkScreenHeader);
      final floating = find.byType(InkFloatingHeader);

      // Home: the brand appears once, in the Home header or in the rail.
      expect(wordmarks, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-header')),
          matching: wordmarks,
        ),
        findsOneWidget,
      );
      expect(headers, findsOneWidget);

      Future<void> check(
        String location, {
        required bool back,
        String? title,
        bool push = false,
        bool header = true,
      }) async {
        if (push) {
          router.push<void>(location);
        } else {
          router.go(location);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        // The wordmark is Home-only; wide windows keep it in the rail.
        expect(wordmarks, findsNothing);
        expect(floating, findsNothing, reason: location);
        expect(headers, header ? findsOneWidget : findsNothing);
        expect(
          find.byType(BackButton),
          header && back ? findsOneWidget : findsNothing,
          reason: location,
        );
        if (title != null && header) {
          expect(
            find.descendant(of: headers, matching: find.text(title)),
            findsOneWidget,
            reason: location,
          );
        }
        final top = MediaQuery.paddingOf(
          tester.element(find.byType(Scaffold).first),
        ).top;
        if (header) {
          // The header consumes the status bar inset itself (a wide settings
          // pane applies it once for its nested pages).
          expect(tester.getTopLeft(headers).dy, 24, reason: location);
          expect(
            tester
                .getTopLeft(
                  find.descendant(of: headers, matching: find.byType(AppBar)),
                )
                .dy,
            greaterThanOrEqualTo(24),
            reason: location,
          );
        }
        expect(top, greaterThanOrEqualTo(0));
      }

      await check('/history', back: true, title: 'Reading history');
      await check(
        '/catalogue/series?library=library-a',
        back: true,
        title: 'Books',
        push: true,
      );
      await check('/downloads', back: true, title: 'Downloads');
      await check(
        '/downloads/series/series-a',
        back: true,
        title: 'Downloaded volumes',
        push: true,
      );
      await check('/settings', back: true, header: !wideSettings);
      for (final (path, title) in [
        ('/settings/language', 'Language'),
        ('/settings/servers', 'Servers and account'),
        ('/settings/library-defaults/library-a', 'Manga shelf'),
      ]) {
        await check(path, back: true, title: title, header: !wideSettings);
        if (wideSettings) {
          expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
        }
      }
      await check(
        '/settings/servers/add',
        back: true,
        title: 'Add server',
        push: true,
      );
      expect(find.byType(AppBar), findsOneWidget);
      await harness.close(tester);
    });

    testWidgets('all detail kinds use the floating Back bubble at $size', (
      tester,
    ) async {
      final harness = await _mount(tester, size);
      final router = harness.container.read(routerProvider);
      for (final location in [
        '/catalogue/series/series-a',
        '/catalogue/library/library-a',
        '/catalogue/collection/collection-a',
        '/catalogue/readlist/readlist-a',
      ]) {
        router.push<void>(location);
        await tester.pumpAndSettle();
        expect(find.byType(InkFloatingHeader), findsOneWidget);
        expect(find.byType(InkScreenHeader), findsNothing, reason: location);
        expect(find.byType(InkoraWordmark), findsNothing);
        final back = find.byKey(const Key('floating-header-back'));
        expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
        // Safe area + margin above the bubble, in every orientation.
        expect(tester.getTopLeft(back).dy, 24 + 8, reason: location);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueDetailScreen), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      await harness.close(tester);
    });

    testWidgets(
      'series content starts below the bubble at rest and while scrolling at $size',
      (tester) async {
        final harness = await _mount(tester, size);
        harness.container
            .read(routerProvider)
            .push<void>('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        final back = find.byKey(const Key('floating-header-back'));
        final bubble = tester.getRect(back);
        final inset = 24 + InkFloatingHeader.barExtent;
        expect(bubble.bottom + 8, inset);
        final hero = find.byType(SeriesHero);
        final read = find.byKey(const Key('detail-read'));
        if (wideSeries) {
          expect(tester.getTopLeft(hero).dy, 0);
          final cover = find.descendant(
            of: hero,
            matching: find.byType(BookCover),
          );
          expect(tester.getTopLeft(cover).dy, greaterThanOrEqualTo(inset));
          expect(tester.getTopLeft(find.byType(SeriesBackdrop)).dy, 0);
          expect(
            tester.getTopLeft(find.byKey(const Key('series-pane-divider'))).dy,
            0,
          );
        } else {
          expect(tester.getTopLeft(hero).dy, greaterThanOrEqualTo(inset));
          // Artwork reaches behind the status bar and Back band; content
          // keeps its own clipped viewport below the controls.
          expect(tester.getTopLeft(find.byType(SeriesBackdrop)).dy, 0);
          final band = tester.widget<DecoratedBox>(
            find.byKey(const Key('floating-header-rest')),
          );
          expect((band.decoration as BoxDecoration).color, Colors.transparent);
        }
        if (wideSeries) {
          final pane = find.byKey(const Key('series-volumes-pane'));
          expect(tester.getTopLeft(pane).dy, 24);
          expect(find.byKey(const Key('floating-header-rest')), findsNothing);
          await tester.tap(back);
          await tester.pumpAndSettle();
          await harness.close(tester);
          return;
        }
        expect(find.byKey(const Key('floating-header-rest')), findsOneWidget);
        // Wide windows have two panes; the About pane drives the header.
        final viewport = find
            .descendant(
              of: find.byType(CatalogueDetailScreen),
              matching: find.byType(CustomScrollView),
            )
            .first;
        // The scroll viewport itself starts below the bubble band, so no
        // content can be painted or hit under the bubble at any offset.
        expect(tester.getTopLeft(viewport).dy, greaterThanOrEqualTo(inset));
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(of: viewport, matching: find.byType(Scrollable))
              .first,
        );
        for (final offset in [1.0, 20.0, 47.0]) {
          scroll.position.jumpTo(offset);
          await tester.pump();
          expect(
            find.byKey(const Key('floating-header-scrolled')),
            findsOneWidget,
          );
        }
        // Between crossings the bar is not rebuilt (same widget instance).
        final scrolledBar = tester.widget(
          find.byKey(const Key('floating-header-scrolled')),
        );
        scroll.position.jumpTo(30);
        await tester.pump();
        expect(
          tester.widget(find.byKey(const Key('floating-header-scrolled'))),
          same(scrolledBar),
        );
        expect(find.byKey(const Key('floating-header-title')), findsNothing);
        scroll.position.jumpTo(48);
        await tester.pump();
        final titled = find.byKey(const Key('floating-header-titled'));
        expect(titled, findsOneWidget);
        expect(
          find.descendant(of: titled, matching: find.text('Moonlit District')),
          findsOneWidget,
        );
        final titledBar = tester.widget(titled);
        for (final offset in [120.0, 260.0]) {
          scroll.position.jumpTo(offset);
          await tester.pump();
          expect(tester.widget(titled), same(titledBar));
        }
        // The Continue/Start button scrolled up never overlaps the bubble:
        // the bubble stays on top for hits, and revealing it lands below.
        expect(tester.getTopLeft(back).dy, bubble.top);
        expect(back.hitTestable(), findsOneWidget);
        scroll.position.jumpTo(80);
        await tester.pump();
        await tester.ensureVisible(read);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(read).dy, greaterThanOrEqualTo(inset));
        expect(read.hitTestable(), findsOneWidget);
        scroll.position.jumpTo(0);
        await tester.pump();
        expect(find.byKey(const Key('floating-header-rest')), findsOneWidget);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueDetailScreen), findsNothing);
        await harness.close(tester);
      },
    );
  }

  testWidgets('Home header keeps search reachable above pinned tools', (
    tester,
  ) async {
    final harness = await _mount(
      tester,
      _phone,
      catalogue: [
        for (var i = 0; i < 60; i++)
          entry('series-$i', kind: CatalogueKind.series, title: 'Series $i'),
      ],
    );
    final header = find.byKey(const Key('home-header'));
    final tools = find.byKey(const Key('catalogue-pinned-tools'));
    final search = find.byKey(const Key('open-search'));
    final history = find.byKey(const Key('reading-history-action'));
    expect(find.descendant(of: header, matching: history), findsOneWidget);
    expect(tester.widget(history), isA<IconButton>());
    expect(find.text('Reading history'), findsNothing);
    final headerRect = tester.getRect(header);
    expect(headerRect.top, 24);
    expect(find.descendant(of: header, matching: search), findsOneWidget);
    expect(find.descendant(of: tools, matching: search), findsNothing);
    expect(tester.getRect(search).right, lessThanOrEqualTo(headerRect.right));
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final visible = tester.widget(header);
    for (final offset in [1.0, 20.0, 200.0, 600.0]) {
      scroll.position.jumpTo(offset);
      await tester.pump();
      expect(tester.widget(header), same(visible));
      expect(header.hitTestable(), findsOneWidget);
      expect(history.hitTestable(), findsOneWidget);
      expect(tester.getRect(header), headerRect);
      expect(
        tester.getTopLeft(tools).dy,
        greaterThanOrEqualTo(headerRect.bottom),
      );
    }
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      true,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
