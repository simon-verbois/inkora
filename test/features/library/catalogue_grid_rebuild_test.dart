import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/volume_list.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

void main() {
  Future<Map<int, int>> scrollAndCount(
    WidgetTester tester,
    Widget Function(IndexedWidgetBuilder builder) sliver,
  ) async {
    final builds = <int, int>{};
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                sliver((context, index) {
                  builds.update(index, (n) => n + 1, ifAbsent: () => 1);
                  return SizedBox(height: 40, child: Text('item $index'));
                }),
              ],
            ),
          ),
        ),
      ),
    );
    // Several small scroll frames that keep item 0 on screen.
    for (var i = 0; i < 5; i++) {
      controller.jumpTo(controller.offset + 3);
      await tester.pump();
    }
    return builds;
  }

  testWidgets(
    'catalogue grid does not rebuild visible cards on scroll frames',
    (tester) async {
      final builds = await scrollAndCount(
        tester,
        (builder) => CatalogueGrid(
          itemCount: 200,
          itemBuilder: builder,
          density: CatalogueDensity.comfortable,
        ),
      );
      expect(builds[0], 1);
    },
  );

  testWidgets('volume list does not rebuild visible rows on scroll frames', (
    tester,
  ) async {
    final builds = await scrollAndCount(
      tester,
      (builder) => VolumeList(itemCount: 200, itemBuilder: builder),
    );
    expect(builds[0], 1);
  });
}
