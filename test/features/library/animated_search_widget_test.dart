import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final prefix in [false, true]) {
      testWidgets('search line is centered at scale $scale, prefix $prefix', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.forest(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: InkSearchField(
                      controller: controller,
                      hint: 'Search',
                      showPrefixIcon: prefix,
                      onChanged: (_) {},
                      onClear: controller.clear,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-search')));
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        final center = tester.getCenter(field).dy;
        final hint = tester.getRect(find.text('Search'));
        expect(hint.center.dy, closeTo(center, 1));
        await tester.enterText(field, 'Atlas');
        await tester.pump();
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        final line = editable.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        expect(editable.localToGlobal(line.center).dy, closeTo(center, 2));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'search expands, focuses and closes with reduced motion $reduced',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final queries = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.forest(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: InkSearchField(
                  controller: controller,
                  hint: 'Search',
                  onChanged: queries.add,
                  onClear: () {
                    controller.clear();
                    queries.add('');
                  },
                ),
              ),
            ),
          ),
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byKey(const Key('open-search')));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, true);
        expect(tester.testTextInput.isVisible, true);
        expect(
          find.byType(AnimatedSize),
          reduced ? findsNothing : findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'Atlas');
        expect(queries, ['Atlas']);
        // The clear action remains tappable outside the inset input surface.
        final clearBounds = tester.getRect(find.byTooltip('Clear search'));
        expect(clearBounds.height, greaterThanOrEqualTo(48));
        await tester.tapAt(Offset(clearBounds.center.dx, clearBounds.top + 1));
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(queries, ['Atlas', '']);
        expect(find.byType(TextField), findsNothing);
        expect(tester.testTextInput.isVisible, false);
      },
    );
  }
}
