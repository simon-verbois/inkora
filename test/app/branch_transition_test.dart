import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/branch_transition.dart';
import 'package:inkora/app/theme/inkora_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'rapid peer changes retain navigator identity without rebuilding content ($reduced)',
      (tester) async {
        final keys = List.generate(3, (_) => GlobalKey<NavigatorState>());
        final builds = [0, 0, 0];
        final children = [
          for (var i = 0; i < 3; i++)
            Navigator(
              key: keys[i],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) {
                  builds[i]++;
                  return Scaffold(body: Text('Branch $i'));
                },
              ),
            ),
        ];
        var index = 0;
        late StateSetter select;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (_, update) {
                  select = update;
                  return BranchTransition(index: index, children: children);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final states = [for (final key in keys) key.currentState];
        for (final next in [1, 2, 0, 2, 1, 0]) {
          select(() => index = next);
          await tester.pump();
          final fade = tester.widget<FadeTransition>(
            find
                .descendant(
                  of: find.byType(BranchTransition),
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          expect(fade.opacity.value, reduced ? 1 : lessThan(1));
          await tester.pump(const Duration(milliseconds: 35));
          final beforeTicks = List.of(builds);
          for (var frame = 0; frame < 4; frame++) {
            await tester.pump(const Duration(milliseconds: 8));
          }
          expect(
            builds,
            beforeTicks,
            reason: 'Animation frames do not rebuild destinations',
          );
          expect(find.text('Branch $next'), findsOneWidget);
          for (var i = 0; i < keys.length; i++) {
            expect(keys[i].currentState, same(states[i]));
            expect(
              TickerMode.valuesOf(keys[i].currentContext!).enabled,
              i == next,
            );
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pump(InkoraMotion.tab);
        expect(find.byType(Navigator, skipOffstage: false), findsNWidgets(4));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
