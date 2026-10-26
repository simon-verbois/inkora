import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('Home toolbar stays rigid during bottom pull at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        resumeEntries: const [],
        catalogue: [
          for (var i = 0; i < 40; i++)
            entry('series-$i', kind: CatalogueKind.series, title: 'Series $i'),
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
      final groups = find.byType(InkHomeToolGroup);
      final rectangles = [
        for (final element in groups.evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      expect(rectangles.length, size.width >= 1000 ? 3 : 1);
      final header = find.byKey(const Key('home-header'));
      final headerBounds = tester.getRect(header);
      final remote = harness.repository.remote as FakeCatalogueRemote;
      final requests = remote.calls;
      final drag = await tester.startGesture(
        Offset(size.width / 2, size.height * .7),
      );
      for (var frame = 0; frame < 8; frame++) {
        await drag.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(header), headerBounds);
        final current = [
          for (final element in groups.evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ];
        expect(
          current,
          rectangles,
          reason:
              'Pinned tool surfaces must stay aligned with their fixed outline',
        );
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        remote.calls,
        requests,
        reason: 'Bottom pulling must not refresh the catalogue',
      );

      // Suppress only the stretch decoration; top pull-to-refresh still works.
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.drag(scroll, const Offset(0, 500));
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
    });
  }
}
