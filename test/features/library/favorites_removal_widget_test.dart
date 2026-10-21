import '../../support/home_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'three destinations and series actions work without favorites at $size',
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
          'libraries',
        ]) {
          await openHomeDestination(tester, destination);
          await tester.pumpAndSettle();
          expect(
            harness.container
                .read(routerProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            destination == 'libraries' ? '/' : '/$destination',
          );
        }
        expect(find.byKey(const Key('navigation-favorites')), findsNothing);
        await openHomeDestination(tester, 'libraries');
        await tester.pumpAndSettle();
        final series = find.byWidgetPredicate(
          (widget) => widget is InkCoverTile && widget.item.id == 'series-a',
        );
        // A series has a single action, so no context menu repeats the tap.
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        await tester.tap(series);
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
