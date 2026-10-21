import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/reader/presentation/reader_chrome.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
    const Size(800, 1280),
    const Size(844, 390),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('reader panels retain accessible actions at $size/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ReaderTopBar(
                        title:
                            'A deliberately long publication title · Volume 12',
                        subtitle: const Text('Chapter 3 · 42 %'),
                        onBack: () => actions.add('back'),
                        actions: [
                          IconButton(
                            tooltip: 'Book details',
                            onPressed: () => actions.add('details'),
                            icon: const Icon(InkIcons.info),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ReaderPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ReaderProgressLine(
                              position: '42 %',
                              detail:
                                  'A long chapter title that must ellipsize',
                            ),
                            ReaderSeekBar(
                              position: 2,
                              count: 12,
                              onSeek: (page) => actions.add('$page'),
                              onPrevious: () => actions.add('previous'),
                              onNext: () => actions.add('next'),
                            ),
                            // The ebook action set: Contents replaces Pages.
                            ReaderActionRow(
                              children: [
                                for (final label in [
                                  'Contents',
                                  'Bookmarks',
                                  'Settings',
                                ])
                                  ReaderQuickAction(
                                    label: label,
                                    icon: InkIcons.bookOpen,
                                    onPressed: () => actions.add(label),
                                  ),
                                ReaderMoreAction(
                                  entries: [
                                    ReaderMenuEntry(
                                      label: 'Search in book',
                                      icon: InkIcons.magnifyingGlass,
                                      onSelected: () => actions.add('search'),
                                    ),
                                    const ReaderMenuEntry(
                                      label: 'Reading progress',
                                      icon: InkIcons.clockCounterClockwise,
                                      onSelected: null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppStrings('de');
        final settings = find.byTooltip(strings.text('Settings'));
        expect(settings.hitTestable(), findsOneWidget);
        final row = [
          'Contents',
          'Bookmarks',
          'Settings',
          'More',
        ].map((label) => find.byTooltip(strings.text(label)));
        expect(
          row.map((finder) => tester.getTopLeft(finder).dy).toSet(),
          hasLength(1),
          reason: 'one action row',
        );
        await tester.tap(settings);
        await tester.tap(find.byTooltip('Book details'));
        await tester.tap(find.byKey(const Key('reader-more')));
        await tester.pumpAndSettle();
        // Disabled entries stay visible but inert.
        await tester.tap(find.text(strings.text('Reading progress')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('Search in book')));
        await tester.pumpAndSettle();
        expect(actions, ['Settings', 'details', 'search']);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
