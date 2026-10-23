import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final status in ['unread', 'completed', 'downloaded']) {
    testWidgets(
      'Home preserves scroll through the $status filter and empty results',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: const [],
          catalogue: [
            for (var i = 0; i < 180; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series $i',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final scroll = find.descendant(
          of: find.byType(CatalogueScreen),
          matching: find.byType(CustomScrollView),
        );
        await tester.drag(scroll, const Offset(0, -550));
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final before = position.pixels;
        expect(before, greaterThan(0));
        await tester.tap(find.byKey(ValueKey('reading-filter-$status')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(before, 1));
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
