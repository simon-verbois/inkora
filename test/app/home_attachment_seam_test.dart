import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';

void main() {
  for (final ratio in [1.0, 1.25, 1.3, 2.125, 3.0]) {
    for (final light in [false, true]) {
      testWidgets(
        'attached Home fill has no dark seam at DPR $ratio/light=$light',
        (tester) async {
          tester.view.physicalSize = Size(600 * ratio, 300 * ratio);
          tester.view.devicePixelRatio = ratio;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = light ? InkoraTheme.light() : InkoraTheme.dark();
          const capture = Key('header-seam-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: theme,
                home: InkHomeHeader(
                  pinned: true,
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: const Stack(
                      children: [
                        Positioned(
                          left: 100,
                          top: 64,
                          child: InkHomeToolGroup(
                            attached: true,
                            horizontalPadding: 0,
                            child: SizedBox(width: 400, height: 56),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final pixels = (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: ratio);
            final width = image.width;
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final bytes = Uint8List.fromList(data.buffer.asUint8List());
            image.dispose();
            return (width, bytes);
          }))!;
          List<int> at(int y) {
            final offset = (y * pixels.$1 + (300 * ratio).floor()) * 4;
            return pixels.$2.sublist(offset, offset + 4);
          }

          final fill = at((84 * ratio).floor());
          // Permit subpixel antialiasing at the join, but no darker band.
          for (var y = (62 * ratio).ceil(); y <= (74 * ratio).floor(); y++) {
            final actual = at(y);
            for (var channel = 0; channel < 3; channel++) {
              expect(
                actual[channel],
                closeTo(fill[channel], 2),
                reason:
                    'Header and attached fill must meet without a stripe at physical row $y',
              );
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
