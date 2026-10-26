import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';

import '../support/ui_harness.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(390, 844),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home outline stays outside controls at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester, resumeEntries: const []);
        addTearDown(() => harness.close(tester));
        const capture = Key('outline-capture');
        await harness.mount(tester, textScale: scale, captureKey: capture);
        for (final element in find.byType(InkHomeToolGroup).evaluate()) {
          final group = find.byWidget(element.widget);
          final rect = tester.getRect(group);
          // The attachment must fit between the header's rounded corners.
          // Resizing only its outline would make it cross the selected chip.
          expect(rect.left, greaterThanOrEqualTo(InkSpace.md + InkRadius.l));
          expect(
            rect.right,
            lessThanOrEqualTo(size.width - InkSpace.md - InkRadius.l),
          );
          final selected = find.descendant(
            of: group,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is InkFilterChip && widget.selected ||
                  widget.key == const Key('reading-filter-menu'),
            ),
          );
          for (final chip in selected.evaluate()) {
            final chipRect = tester.getRect(find.byWidget(chip.widget));
            expect(chipRect.left, greaterThanOrEqualTo(rect.left + 12));
            expect(chipRect.right, lessThanOrEqualTo(rect.right - 12));
            if (size.width == 390 && scale == 1) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              final pixels = (await tester.runAsync(() async {
                final image = await boundary.toImage();
                final width = image.width;
                final data = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final bytes = Uint8List.fromList(data.buffer.asUint8List());
                image.dispose();
                return (width, bytes);
              }))!;
              List<int> at(int x) {
                final offset = (chipRect.center.dy.floor() * pixels.$1 + x) * 4;
                return pixels.$2.sublist(offset, offset + 4);
              }

              // The old narrowed outline crossed this plain part of the
              // selected pill, ten pixels from its left edge.
              final fill = at((chipRect.left + 14).floor());
              for (var dx = 8; dx <= 13; dx++) {
                expect(at((chipRect.left + dx).floor()), fill);
              }
            }
          }
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }
}
