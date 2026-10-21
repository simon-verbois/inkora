import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';

void main() {
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
