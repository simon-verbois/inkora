import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/catalogue_tools_sliver.dart';

void main() {
  testWidgets(
    'toolbar crossings notify once without rebuilding scroll content',
    (tester) async {
      final controller = ScrollController();
      final height = ValueNotifier(80.0);
      addTearDown(controller.dispose);
      addTearDown(height.dispose);
      final crossings = <bool>[];
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 300)),
                CatalogueToolsSliver(
                  headerExtent: 64,
                  onObscuredChanged: crossings.add,
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) => SizedBox(height: value),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (_) {
                      builds++;
                      return const SizedBox(height: 2000);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(crossings, [false]);
      for (final offset in [310.0, 315.0, 316.0, 320.0, 340.0, 360.0]) {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
      }
      expect(crossings, [false, true]);
      expect(builds, 1);
      height.value = 160;
      await tester.pumpAndSettle();
      expect(crossings, [false, true, false]);
      controller.jumpTo(396);
      await tester.pumpAndSettle();
      expect(crossings, [false, true, false, true]);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(crossings, [false, true, false, true, false]);
      expect(builds, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
