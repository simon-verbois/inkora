import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_settings.dart';
import 'package:inkora/reader/presentation/ebook_settings_controls.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
      'ebook controls commit typography on release and fit $size at 200%',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final changes = <(String, Object)>[];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EbookSettingsControls(
                      settings: const EbookSettings(),
                      onChanged: (key, value) => changes.add((key, value)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final slider = find.byType(Slider).first;
        await tester.ensureVisible(slider);
        final gesture = await tester.startGesture(tester.getCenter(slider));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(changes, isEmpty);
        await gesture.up();
        await tester.pump();
        expect(changes.length, 1);
        expect(changes.single.$1, 'fontSize');
        final margins = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == 'Page margins',
        );
        await tester.ensureVisible(margins);
        await tester.tap(margins);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wide margins').last);
        await tester.pumpAndSettle();
        expect(changes.last, ('margins', 1.5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
