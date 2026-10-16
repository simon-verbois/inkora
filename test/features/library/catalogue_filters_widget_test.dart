import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/catalogue_filters_sheet.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'metadata sheet combines/reset values and preserves draft at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final result = <CatalogueFilterResult>[];
          final initial = MetadataFilters.from({
            CatalogueFacet.publisher: 'Fixture Publisher',
          });
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final value =
                          await showModalBottomSheet<CatalogueFilterResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => SafeArea(
                              child: SizedBox(
                                height: size.height * .8,
                                child: CatalogueFiltersSheet(
                                  filters: initial,
                                  showUnavailable: true,
                                  options: Future.value({
                                    CatalogueFacet.genres: [
                                      'Adventure',
                                      'Fantasy',
                                    ],
                                    CatalogueFacet.publisher: [
                                      'Fixture Publisher',
                                    ],
                                  }),
                                ),
                              ),
                            ),
                          );
                      if (value != null) result.add(value);
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('List view'), findsNothing);
          final genre = find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<String> &&
                widget.decoration.labelText == 'Genres',
          );
          await tester.ensureVisible(genre);
          await tester.tap(genre);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Fantasy').last);
          await tester.pumpAndSettle();
          expect(initial.values.containsKey(CatalogueFacet.genres), false);
          await tester.ensureVisible(find.text('Apply filters'));
          await tester.tap(find.text('Apply filters'));
          await tester.pumpAndSettle();
          expect(result.single.filters.values, {
            CatalogueFacet.genres: 'Fantasy',
            CatalogueFacet.publisher: 'Fixture Publisher',
          });
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reset'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Apply filters'));
          await tester.tap(find.text('Apply filters'));
          await tester.pumpAndSettle();
          expect(result.last.filters.isEmpty, true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
