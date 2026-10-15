import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  for (final raster in [true, false]) {
    testWidgets('unavailable resume card remains disabled (raster $raster)', (
      tester,
    ) async {
      var opened = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ResumeCarousel(
                entries: [
                  ResumeEntry(
                    item: entry('removed', available: false),
                    pageIndex: 0,
                    pageCount: 10,
                    fraction: 0,
                    raster: raster,
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            name: 'reader',
            path: '/reader/:id',
            builder: (_, _) {
              opened++;
              return const Scaffold(body: Text('Reader'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coverRepositoryProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogueCard>(find.byType(CatalogueCard)).item.canOpen,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('resume-removed')));
      await tester.pumpAndSettle();
      expect(opened, 0);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('multiple volumes render one series cover', (tester) async {
    final entries = [
      for (var i = 0; i < 3; i++)
        ResumeEntry(
          item: entry('book-$i', seriesId: i < 2 ? 'shared' : 'other'),
          seriesTitle: i < 2 ? 'Shared series' : 'Other series',
          pageIndex: 0,
          pageCount: 10,
          fraction: 0,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coverRepositoryProvider.overrideWith((ref) async => null)],
        child: MaterialApp(
          home: Scaffold(body: ResumeCarousel(entries: entries)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shelf = tester.widget<CatalogueShelf>(find.byType(CatalogueShelf));
    expect(shelf.items.map((item) => item.id), ['shared', 'other']);
    expect(
      shelf.items.every((item) => item.kind == CatalogueKind.series),
      isTrue,
    );
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'show series, volume and pages then open the exact book directly at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final entries = List.generate(
            4,
            (index) => ResumeEntry(
              item: entry(
                'book-$index',
                title: 'A long saved book title for volume ${index + 1}',
                seriesId: 'series-$index',
              ),
              seriesTitle: 'A long saved series title ${index + 1}',
              pageIndex: index + 1,
              pageCount: 10,
              fraction: 0,
              raster: index.isEven || scale == 1,
              pageKnown: index != 1,
              onDeck: index == 0,
            ),
          );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [ResumeCarousel(entries: entries)],
                  ),
                ),
              ),
              GoRoute(
                name: 'reader',
                path: '/read/:id',
                builder: (_, state) =>
                    Scaffold(body: Text('book ${state.pathParameters['id']}')),
              ),
              GoRoute(
                name: 'catalogue-detail',
                path: '/details/:kind/:id',
                builder: (_, state) => Scaffold(
                  body: Text(
                    '${state.pathParameters['kind']} ${state.pathParameters['id']}',
                  ),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                coverRepositoryProvider.overrideWith((ref) async => null),
              ],
              child: MaterialApp.router(
                theme: InkoraTheme.dark(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('In progress').hitTestable(), findsOneWidget);
          expect(find.text('0/10 pages').hitTestable(), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('resume-book-0')),
              matching: find.byType(LinearProgressIndicator),
            ),
            findsNothing,
          );
          await tester.tap(find.byKey(const ValueKey('resume-book-0')));
          await tester.pumpAndSettle();
          expect(find.text('book book-0'), findsOneWidget);
          expect(router.canPop(), isTrue);
          router.pop();
          await tester.pumpAndSettle();
          if (scale == 1 && size.width < 840) {
            final covers = find.byType(BookCover);
            expect(
              tester.getBottomRight(covers.at(2)).dx,
              lessThan(size.width - 16),
            );
            expect(
              tester.getTopLeft(covers.at(3)).dx,
              lessThan(size.width - 16),
            );
            expect(
              tester.getBottomRight(covers.at(3)).dx,
              greaterThan(size.width - 16),
            );
          }
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('resume-book-3')),
            160,
            scrollable: find.descendant(
              of: find.byType(ResumeCarousel),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(scale == 1 ? 'Page 5/10' : '40% read').hitTestable(),
            findsOneWidget,
          );
          final series = find.text('A long saved series title 4');
          final volume = find.text('A long saved book title for volume 4');
          final pages = find.text(scale == 1 ? 'Page 5/10' : '40% read');
          expect(
            series.hitTestable(),
            scale == 1 ? findsOneWidget : findsNothing,
          );
          expect(volume.hitTestable(), findsOneWidget);
          if (scale == 1) {
            expect(
              tester.getBottomLeft(series).dy,
              lessThanOrEqualTo(tester.getTopLeft(volume).dy),
            );
          }
          expect(
            tester.getBottomLeft(volume).dy,
            lessThanOrEqualTo(tester.getTopLeft(pages).dy),
          );
          final progress = find.descendant(
            of: find.byKey(const ValueKey('resume-book-3')),
            matching: find.byType(LinearProgressIndicator),
          );
          expect(tester.widget<LinearProgressIndicator>(progress).value, .4);
          await tester.tap(find.byKey(const ValueKey('resume-book-3')));
          await tester.pumpAndSettle();
          expect(find.text('book book-3'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
