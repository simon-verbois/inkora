import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/app/widgets/ink_snap_sheet.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final reduced in [false, true]) {
      for (final region in ['list', 'title', 'blank', 'filters']) {
        testWidgets('popup dismisses from $region at $size/reduced=$reduced', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            preferences: UiPreferences(reduceMotion: reduced),
          );
          addTearDown(() => harness.close(tester));
          await harness.mount(tester);
          await tester.tap(
            find.byKey(
              Key(
                region == 'filters'
                    ? 'catalogue-floating-filters'
                    : 'catalogue-floating-library',
              ),
            ),
          );
          await tester.pumpAndSettle();
          final sheet = find.byKey(const Key('ink-sheet-surface'));
          final bounds = tester.getRect(sheet);
          final start = switch (region) {
            'list' => tester.getCenter(
              find.byKey(const Key('library-choice-all')),
            ),
            'title' => Offset(bounds.center.dx, bounds.top + 70),
            'blank' => Offset(bounds.center.dx, bounds.bottom - 50),
            _ => Offset(bounds.center.dx, bounds.top + bounds.height * .6),
          };
          await tester.flingFrom(start, const Offset(0, 450), 1500);
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(find.byKey(const Key('home-header')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        });
      }
    }
  }
  for (final explicit in [false, true]) {
    testWidgets(
      'scrolling returns to top before downward dismissal (explicit=$explicit)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final custom = ScrollController();
        addTearDown(custom.dispose);
        late BuildContext owner;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                owner = context;
                return const Scaffold(body: Text('Underlying page'));
              },
            ),
          ),
        );
        showInkPopup<void>(
          context: owner,
          child: ListView(
            controller: explicit ? custom : null,
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 56, child: Text('Row $i')),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView);
        final element = tester.element(list);
        final scroll = explicit
            ? custom
            : InkSheetViewport.scrollControllerOf(element)!;
        scroll.jumpTo(300);
        await tester.pumpAndSettle();
        final sheet = find.byKey(const Key('ink-sheet-surface'));
        final bounds = tester.getRect(sheet);
        final gesture = await tester.startGesture(
          Offset(190, bounds.top + 150),
        );
        for (var i = 0; i < 4; i++) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(sheet), bounds);
          expect(scroll.offset, greaterThan(0));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.flingFrom(
          Offset(190, tester.getRect(sheet).top + 150),
          const Offset(0, 450),
          1500,
        );
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
