import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_divider.dart';

void main() {
  testWidgets('horizontal and vertical rules fade at both ends', (
    tester,
  ) async {
    const boundary = Key('rule-capture');
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: const ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  children: [
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: InkDivider(height: 1, color: Colors.black),
                    ),
                    Positioned(
                      left: 20,
                      top: 0,
                      bottom: 0,
                      child: InkVerticalDivider(width: 1, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final samples = await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
          .toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int channel(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
      final result = [
        channel(0, 20),
        channel(149, 20),
        channel(299, 20),
        channel(20, 0),
        channel(20, 149),
        channel(20, 299),
      ];
      image.dispose();
      return result;
    });
    for (final i in [0, 2, 3, 5]) {
      expect(samples![i], greaterThan(250));
    }
    for (final i in [1, 4]) {
      expect(samples![i], lessThan(5));
    }
  });
  testWidgets('scrolling list rules reuses local shaders and row widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 50,
            itemExtent: 56,
            itemBuilder: (context, index) => InkBottomDivider(
              key: ValueKey(index),
              child: SizedBox(height: 56, child: Text('Row $index')),
            ),
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey(0));
    final stable = tester.widget(first);
    final paint = find.descendant(
      of: first,
      matching: find.byType(CustomPaint),
    );
    final painter =
        tester.widget<CustomPaint>(paint).painter! as InkRulePainter;
    final builds = painter.gradientBuilds;
    expect(builds, 1);
    final drag = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 12; i++) {
      await drag.moveBy(const Offset(0, -2));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget(first), same(stable));
      expect(tester.widget<CustomPaint>(paint).painter, same(painter));
      expect(painter.gradientBuilds, builds);
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
