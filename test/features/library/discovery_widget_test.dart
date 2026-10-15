import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/application/discovery_providers.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/library_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/discovery_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'Five sections stay fixed through navigation, offline pull and midnight at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var now = DateTime(2026, 10, 12);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [],
          discoveryClock: () => now,
        );
        addTearDown(() => harness.close(tester));
        await tester.runAsync(() async {
          await harness.repository.store.stage(
            'discovery',
            List.generate(120, (i) => series('series-$i')),
          );
          await harness.repository.store.publish('discovery', now, () => true);
        });
        (harness.repository.remote as FakeCatalogueRemote).failKind =
            CatalogueKind.library;
        await harness.mount(tester);
        final panel = find.byKey(const Key('home-discovery'));
        final shelf = find.descendant(
          of: panel,
          matching: find.byType(CatalogueShelf),
        );
        List<String> ids() => tester
            .widget<CatalogueShelf>(shelf)
            .items
            .map((item) => item.id)
            .toList();
        final initial = ids();
        List<String> allIds() => harness.container
            .read(discoverySectionsProvider)
            .requireValue
            .expand((page) => page.items.map((item) => item.id))
            .toList();
        final initialAll = allIds();
        expect(initial, hasLength(10));
        expect(find.text('Discover · Library surprises'), findsOneWidget);
        final router = harness.container.read(routerProvider);
        router.go('/libraries');
        await tester.pumpAndSettle();
        router.go('/');
        await tester.pumpAndSettle();
        expect(ids(), initial);
        expect(allIds(), initialAll);

        // Drag the actual Home scroll view while metadata refresh fails offline.
        final home = find.byType(LibraryScreen);
        final vertical = find
            .descendant(of: home, matching: find.byType(Scrollable))
            .first;
        tester.state<ScrollableState>(vertical).position.jumpTo(0);
        await tester.drag(vertical, const Offset(0, 650));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        final refreshed = ids();
        expect(refreshed, initial);
        expect(allIds(), initialAll);
        expect(
          find.textContaining('Saved catalogue remains available.'),
          findsOneWidget,
        );
        final horizontal = find.descendant(
          of: shelf,
          matching: find.byType(Scrollable),
        );
        expect(tester.state<ScrollableState>(horizontal).position.pixels, 0);

        now = now.add(const Duration(days: 1));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 31));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(
          harness.container.read(discoveryLaunchDateProvider),
          DateTime(2026, 10, 12),
        );
        expect(ids(), initial);
        expect(allIds(), initialAll);
        final sections = harness.container
            .read(discoverySectionsProvider)
            .requireValue;
        expect(sections, hasLength(3));
        final visibleIds = sections
            .expand((page) => page.items.map((item) => item.id))
            .toList();
        expect(visibleIds, hasLength(30));
        expect(visibleIds.toSet(), hasLength(30));
        // Scroll through both additional rows: all five Home sections are real.
        for (final index in [1, 2]) {
          final additional = find.byKey(ValueKey('home-discovery-$index'));
          await tester.scrollUntilVisible(
            additional,
            200,
            scrollable: vertical,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: additional,
              matching: find.byType(CatalogueShelf),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
