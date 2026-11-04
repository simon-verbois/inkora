import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_snap_sheet.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/catalogue_filters_sheet.dart';

void main() {
  testWidgets(
    'short filter content still expands without repeating count queries',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext owner;
      var counts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              owner = context;
              return const Scaffold(body: Text('Underlying page'));
            },
          ),
        ),
      );
      showInkPopup<void>(
        context: owner,
        child: CatalogueFiltersSheet(
          options: Future.value({}),
          filters: const MetadataFilters(),
          showReadingFilters: true,
          count: (filters, unavailable) async {
            counts++;
            return 1;
          },
        ),
      );
      await tester.pumpAndSettle();
      final body = find.descendant(
        of: find.byType(CatalogueFiltersSheet),
        matching: find.byType(SingleChildScrollView),
      );
      final scroll = tester.widget<SingleChildScrollView>(body).controller!;
      expect(scroll.position.maxScrollExtent, 0);
      final stable = tester.widget(find.byType(CatalogueFiltersSheet));
      final before = counts;
      final gesture = await tester.startGesture(tester.getCenter(body));
      for (var i = 0; i < 24; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
        expect(scroll.offset, 0);
        expect(counts, before);
        expect(tester.widget(find.byType(CatalogueFiltersSheet)), same(stable));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('ink-sheet-surface'))).height,
        closeTo(844, 1),
      );
      expect(counts, before);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(1280, 800),
    const Size(844, 390),
  ]) {
    for (final reduced in [false, true]) {
      testWidgets('body expands before scrolling at $size/reduced=$reduced', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late BuildContext owner;
        late ScrollController scroll;
        var builds = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                owner = context;
                return const Scaffold(body: Text('Underlying page'));
              },
            ),
          ),
        );
        showInkPopup<void>(
          context: owner,
          title: 'Filters',
          child: Builder(
            builder: (context) {
              builds++;
              scroll = InkSheetViewport.scrollControllerOf(context)!;
              return SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    for (var i = 0; i < 50; i++)
                      SizedBox(height: 56, child: Text('Filter $i')),
                  ],
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        final surface = find.byKey(const Key('ink-sheet-surface'));
        final initial = tester.getRect(surface);
        final stableBuilds = builds;
        final gesture = await tester.startGesture(
          Offset(size.width / 2, size.height - 100),
        );
        for (var i = 0; i < 24; i++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 16));
          final bounds = tester.getRect(surface);
          if (bounds.height < size.height - 1) expect(scroll.offset, 0);
          expect(builds, stableBuilds);
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester.getRect(surface).height,
          greaterThanOrEqualTo(initial.height),
        );
        expect(tester.getRect(surface).height, closeTo(size.height, 1));
        await tester.dragFrom(
          Offset(size.width / 2, size.height - 100),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        expect(builds, stableBuilds);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
