import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
        'Home stretches at both edges with fixed chrome at $size (reduce motion $reduceMotion)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            resumeEntries: const [],
            preferences: UiPreferences(reduceMotion: reduceMotion),
            catalogue: [
              for (var i = 0; i < 40; i++)
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
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: scroll, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final groups = find.byKey(const Key('catalogue-floating-actions'));
          final rectangles = [
            for (final element in groups.evaluate())
              tester.getRect(find.byWidget(element.widget)),
          ];
          expect(rectangles.length, 1);
          final header = find.byKey(const Key('home-header'));
          final headerBounds = tester.getRect(header);
          final effects = find.descendant(
            of: scroll,
            matching: find.byType(StretchEffect),
          );
          expect(effects, reduceMotion ? findsNothing : findsOneWidget);
          final grid = find.byType(CatalogueGrid);
          final stableGrid = tester.widget(grid);
          final bottomStrengths = <double>[];
          final remote = harness.repository.remote as FakeCatalogueRemote;
          final requests = remote.calls;
          final drag = await tester.startGesture(
            Offset(size.width / 2, size.height * .7),
          );
          for (var frame = 0; frame < 8; frame++) {
            await drag.moveBy(const Offset(0, -30));
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.getRect(header), headerBounds);
            expect(tester.widget(grid), same(stableGrid));
            if (!reduceMotion) {
              bottomStrengths.add(
                tester.widget<StretchEffect>(effects).stretchStrength,
              );
            }
            final current = [
              for (final element in groups.evaluate())
                tester.getRect(find.byWidget(element.widget)),
            ];
            expect(
              current,
              rectangles,
              reason: 'Floating tools must remain fixed while the catalogue is overscrolled',
            );
          }
          if (!reduceMotion) {
            expect(bottomStrengths.any((value) => value < 0), isTrue);
          }
          await drag.up();
          await tester.pumpAndSettle();
          expect(
            remote.calls,
            requests,
            reason: 'Bottom pulling must not refresh the catalogue',
          );

          // Top stretch and pull-to-refresh retain their separate owners.
          position.jumpTo(0);
          await tester.pumpAndSettle();
          final topStrengths = <double>[];
          final topDrag = await tester.startGesture(
            Offset(size.width / 2, size.height * .4),
          );
          for (var frame = 0; frame < 8; frame++) {
            await topDrag.moveBy(const Offset(0, 70));
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.getRect(header), headerBounds);
            expect(tester.getRect(groups), rectangles.single);
            if (!reduceMotion) {
              topStrengths.add(
                tester.widget<StretchEffect>(effects).stretchStrength,
              );
            }
          }
          if (!reduceMotion) {
            expect(topStrengths.any((value) => value > 0), isTrue);
          }
          await topDrag.up();
          for (var turn = 0; turn < 20 && remote.calls == requests; turn++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(remote.calls, greaterThan(requests));
          await tester.runAsync(
            () => harness.repository.status.firstWhere((state) => !state.busy),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }
}
