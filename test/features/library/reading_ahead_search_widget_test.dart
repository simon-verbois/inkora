import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/features/library/data/saved_search_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/saved_catalogue_search.dart';
import 'package:inkora/offline/data/download_ahead_store.dart';

import 'series_detail_widget_test.dart' show openSeries;

Future<void> settleSavedSearches(WidgetTester tester) async {
  // Drift delivers on fake time; the bounded JSON worker uses real isolate
  // time. Let both advance before asking animations to settle.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in languageNames.keys) {
    testWidgets(
      'automatic downloads and saved searches in $locale at 320dp / 200%',
      (tester) async {
        final harness = await openSeries(
          tester,
          size: const Size(320, 900),
          textScale: 2,
          locale: locale,
        );
        final ahead = DownloadAheadStore(
          harness.database,
          harness.repository.store.accountId,
        );
        await tester.tap(find.byKey(const Key('detail-download')));
        await tester.pumpAndSettle();
        final two = find.byKey(const Key('download-series-ahead-2'));
        await tester.ensureVisible(two);
        await tester.tap(two);
        await tester.pumpAndSettle();
        final accept = find.byKey(const Key('ink-confirm-accept'));
        expect(tester.getRect(accept).bottom, lessThanOrEqualTo(900));
        await tester.tap(accept);
        await tester.pumpAndSettle();
        expect(await tester.runAsync(() => ahead.count('series-a')), 2);
        await settleSavedSearches(tester);
        // Let the localized floating confirmation clear the compact actions.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('detail-download')));
        await tester.pumpAndSettle();
        final off = find.byKey(const Key('download-series-ahead-off'));
        await tester.ensureVisible(off);
        await tester.tap(off);
        await tester.pumpAndSettle();
        // Cancelling a new draft must leave the active automatic rule intact.
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(await tester.runAsync(() => ahead.count('series-a')), 2);
        await settleSavedSearches(tester);
        harness.container.read(routerProvider).go('/catalogue/book');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalogue-saved-searches')));
        await settleSavedSearches(tester);
        expect(
          find.text(AppStrings(locale).text('Saved searches')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('saved-search-name')),
          'Fixture search',
        );
        await tester.pump();
        final save = find.byKey(const Key('saved-search-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await settleSavedSearches(tester);
        expect(
          find.byKey(const ValueKey('saved-search-Fixture search')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets(
      'recall restores combined filters, saving captures the latest text, deletion persists at $size',
      (tester) async {
        final harness = await openSeries(tester, size: size);
        final store = SavedSearchStore(
          harness.database,
          harness.repository.store.accountId,
        );
        final filters = MetadataFilters.from({
          CatalogueFacet.authors: 'Writer Name',
          CatalogueFacet.genres: 'Mystery',
        }, readingStatus: ReadingStatus.inProgress);
        await tester.runAsync(
          () => store.save(
            SavedCatalogueSearch(
              'Mystery reading',
              CatalogueQuery(
                kind: CatalogueKind.series,
                readingUnits: true,
                libraryId: 'library-a',
                filters: filters,
                sort: CatalogueSort.titleDescending,
                showUnavailable: false,
              ),
            ),
          ),
        );
        harness.container.read(routerProvider).go('/catalogue/series');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalogue-saved-searches')));
        await settleSavedSearches(tester);
        await tester.tap(
          find.byKey(const ValueKey('saved-search-Mystery reading')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Moonlit District'), findsWidgets);
        final reading = tester.widget<InkFilterChip>(
          find.byKey(const ValueKey('reading-filter-inProgress')),
        );
        expect(reading.selected, isTrue);
        final search = find.byKey(const Key('catalogue-search'));
        final field = find.descendant(
          of: search,
          matching: find.byType(TextField),
        );
        if (field.evaluate().isEmpty) {
          await tester.tap(find.byKey(const Key('open-search')).first);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(TextField)),
          'Moonlit',
        );
        // No debounce wait: opening saved searches must capture the whole draft.
        await tester.tap(find.byKey(const Key('catalogue-saved-searches')));
        await settleSavedSearches(tester);
        await tester.enterText(
          find.byKey(const Key('saved-search-name')),
          'Named query',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('saved-search-save')));
        await settleSavedSearches(tester);
        final searches = await tester.runAsync(() => store.watch().first);
        final named = searches!.firstWhere((s) => s.name == 'Named query');
        expect(named.query.search, 'Moonlit');
        expect(named.query.filters, filters);
        expect(named.query.libraryId, 'library-a');
        expect(named.query.sort, CatalogueSort.titleDescending);
        await tester.tap(
          find.byKey(const ValueKey('saved-search-remove-Mystery reading')),
        );
        await settleSavedSearches(tester);
        expect(
          find.byKey(const ValueKey('saved-search-Mystery reading')),
          findsNothing,
        );
        expect(await tester.runAsync(() => store.watch().first), hasLength(1));
        await harness.close(tester);
      },
    );
  }
}
