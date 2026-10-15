import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/presentation/volume_list.dart';

void main() {
  for (final (width, scale, columns) in [
    (390.0, 1.0, 1),
    (800.0, 1.0, 2),
    (839.0, 1.0, 2),
    (840.0, 1.0, 3),
    (880.0, 1.0, 3),
    (936.0, 1.0, 3),
    (1136.0, 1.0, 3),
    (936.0, 1.3, 2),
    (936.0, 2.0, 1),
  ]) {
    testWidgets('volumes retain sequence and trailing cells at $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  VolumeList(
                    itemCount: 8,
                    itemBuilder: (_, index) => ListTile(
                      key: ValueKey(index),
                      title: Text('Volume $index'),
                      trailing: const Icon(Icons.download),
                      onTap: () => opened.add(index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byKey(const ValueKey(0)));
      for (var index = 0; index < columns; index++) {
        final cell = tester.getRect(find.byKey(ValueKey(index)));
        expect(cell.top, first.top);
        expect(cell.width, closeTo(first.width, .01));
      }
      expect(
        tester.getTopLeft(find.byKey(ValueKey(columns))).dy,
        greaterThan(first.top),
      );
      // Eight items leave an incomplete final row at three columns.
      final last = tester.getRect(find.byKey(const ValueKey(7)));
      expect(last.width, closeTo(first.width, .01));
      await tester.tap(find.text('Volume 7'));
      expect(opened, [7]);
      expect(tester.takeException(), isNull);
    });
  }
}
