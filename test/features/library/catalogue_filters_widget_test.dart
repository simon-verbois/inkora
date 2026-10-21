import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/catalogue_filters_sheet.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
      'chip filters, search, debounced count and reset at $size / $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final result = <CatalogueFilterResult>[];
        final counted = <MetadataFilters>[];
        // Reading status and Downloaded belong to the filter bar: the sheet
        // passes them through untouched.
        final initial = MetadataFilters.from(
          {CatalogueFacet.publisher: 'Fixture Publisher'},
          readingStatus: ReadingStatus.unread,
          downloadedOnly: true,
        );
        final genres = [for (var i = 0; i < 18; i++) 'Genre $i', 'Fantasy'];
        Future<int> count(MetadataFilters filters, bool unavailable) async {
          counted.add(filters);
          return 40 - 10 * filters.values.length + (unavailable ? 1 : 0);
        }

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: InkoraTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final value = await showInkSheet<CatalogueFilterResult>(
                        context: context,
                        child: CatalogueFiltersSheet(
                          filters: initial,
                          showUnavailable: false,
                          count: count,
                          options: Future.value({
                            CatalogueFacet.mediaType: [
                              'application/epub+zip',
                              'application/zip',
                            ],
                            CatalogueFacet.status: ['ONGOING', 'ENDED'],
                            CatalogueFacet.genres: genres,
                            CatalogueFacet.publisher: ['Fixture Publisher'],
                          }),
                        ),
                      );
                      if (value != null) result.add(value);
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Filters'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('Reading status'), findsNothing);
        expect(find.text('Downloaded'), findsNothing);
        expect(find.text('Publication status'), findsOneWidget);
        // Server MIME types read as short formats.
        expect(find.text('EPUB'), findsOneWidget);
        expect(find.text('CBZ'), findsOneWidget);
        // Opening counts once, immediately.
        expect(counted, hasLength(1));
        expect(find.text('Show results (30)'), findsOneWidget);

        // Long lists show 12 values and a +N chip; search narrows locally.
        final more = find.byKey(const ValueKey('filter-more-genres'));
        expect(find.text('+7'), findsOneWidget);
        expect(find.text('Fantasy'), findsNothing);
        await tester.ensureVisible(more);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.text('Fantasy'), findsOneWidget);
        final search = find.byKey(const ValueKey('filter-search-genres'));
        await tester.ensureVisible(search);
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
        await tester.enterText(search, 'fanta');
        await tester.pumpAndSettle();
        expect(find.text('Genre 3'), findsNothing);
        // Searching never queries.
        expect(counted, hasLength(1));

        // Two quick selections produce one count query after the delay.
        final fantasy = find.byKey(const ValueKey('filter-genres-Fantasy'));
        await tester.ensureVisible(fantasy);
        await tester.tap(fantasy);
        await tester.pump(const Duration(milliseconds: 50));
        final epub = find.byKey(
          const ValueKey('filter-mediaType-application/epub+zip'),
        );
        await tester.ensureVisible(epub);
        await tester.tap(epub);
        await tester.pump(const Duration(milliseconds: 100));
        expect(counted, hasLength(1));
        await tester.pump(CatalogueFiltersSheet.countDelay);
        await tester.pumpAndSettle();
        expect(counted, hasLength(2));
        expect(find.text('Show results (10)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('filters-apply')));
        await tester.pumpAndSettle();
        expect(result.single.filters.values, {
          CatalogueFacet.genres: 'Fantasy',
          CatalogueFacet.mediaType: 'application/epub+zip',
          CatalogueFacet.publisher: 'Fixture Publisher',
        });
        expect(result.single.filters.readingStatus, ReadingStatus.unread);
        expect(result.single.filters.downloadedOnly, isTrue);
        expect(result.single.showUnavailable, isFalse);

        // Reset (header) clears metadata choices only.
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filters-reset')));
        await tester.pump(CatalogueFiltersSheet.countDelay);
        await tester.pumpAndSettle();
        expect(find.text('Show results (40)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('filters-apply')));
        await tester.pumpAndSettle();
        expect(result.last.filters.values, isEmpty);
        expect(result.last.filters.readingStatus, ReadingStatus.unread);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
