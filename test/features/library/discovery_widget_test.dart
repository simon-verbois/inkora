import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/discovery_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'library landing avoids removed discovery/recent work at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        for (final location in [
          '/',
          '/downloads',
          '/settings',
          '/',
          '/libraries',
        ]) {
          harness.container.read(routerProvider).go(location);
          await tester.pumpAndSettle();
        }
        expect(
          harness.container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
        expect(find.byKey(const Key('catalogue-pinned-tools')), findsOneWidget);
        expect(find.byKey(const Key('catalogue-grid')), findsOneWidget);
        expect(find.byKey(const Key('home-discovery')), findsNothing);
        expect(harness.container.exists(discoverySectionsProvider), isFalse);
        expect(
          harness.container.exists(
            cataloguePageProvider(
              const CatalogueQuery(
                kind: CatalogueKind.series,
                readingUnits: true,
                sort: CatalogueSort.recentlyUpdated,
                pageSize: 10,
                showUnavailable: false,
              ),
            ),
          ),
          isFalse,
        );
        expect(find.text('Your next great read'), findsNothing);
        expect(find.text('Continue reading'), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
