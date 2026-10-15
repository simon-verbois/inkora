import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'four destinations and series actions work without favorites at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        for (final destination in [
          'libraries',
          'downloads',
          'settings',
          'home',
        ]) {
          await tester.tap(find.byKey(ValueKey('navigation-$destination')));
          await tester.pumpAndSettle();
          expect(
            harness.container
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            destination == 'home' ? '/' : '/$destination',
          );
        }
        expect(find.byKey(const Key('navigation-favorites')), findsNothing);
        await tester.tap(find.byKey(const Key('navigation-libraries')));
        await tester.pumpAndSettle();
        final series = find.byWidgetPredicate(
          (widget) => widget is CatalogueCard && widget.item.id == 'series-a',
        );
        await tester.tap(
          find.descendant(
            of: series,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<String>), findsOneWidget);
        expect(find.text('View details'), findsOneWidget);
        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('detail-read')), findsOneWidget);
        expect(find.byTooltip('Add to favorites'), findsNothing);
        expect(find.byTooltip('Remove from favorites'), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
