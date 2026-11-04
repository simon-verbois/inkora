import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
      'Home popup tools apply sort/library with permanent actions at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: const [],
          catalogue: [
            entry(
              'library-a',
              kind: CatalogueKind.library,
              title: 'First shelf',
            ),
            entry(
              'library-b',
              kind: CatalogueKind.library,
              title: 'Second shelf',
            ),
            for (var i = 0; i < 180; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                libraryId: i.isEven ? 'library-a' : 'library-b',
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        expect(find.byType(InkFilterBar), findsNothing);
        expect(find.byKey(const Key('catalogue-tools')), findsNothing);
        final library = find.byKey(const Key('catalogue-floating-library'));
        final filters = find.byKey(const Key('catalogue-floating-filters'));
        expect(tester.getSize(library).width, 60);
        await tester.tap(library);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('library-choice-library-b')));
        await tester.pumpAndSettle();
        expect(find.text('Series 000'), findsNothing);
        expect(find.text('Series 001'), findsOneWidget);
        await tester.tap(filters);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalogue-sort')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is CheckedPopupMenuItem<CatalogueSort> &&
                w.value == CatalogueSort.titleDescending,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('catalogue-view')), findsNothing);
        await tester.tap(find.byKey(const Key('filters-apply')));
        await tester.pumpAndSettle();

        expect(find.text('Series 179'), findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pumpAndSettle();
        final header = find.byKey(const Key('home-header'));
        expect(header.hitTestable(), findsOneWidget);
        final floating = find.byKey(const Key('catalogue-floating-actions'));
        expect(floating, findsOneWidget);
        expect(
          find.byKey(const Key('catalogue-floating-library')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('catalogue-floating-filters')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.getRect(floating).right, greaterThan(size.width - 80));
        expect(
          tester.getRect(floating).bottom,
          lessThanOrEqualTo(size.height - 16),
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
