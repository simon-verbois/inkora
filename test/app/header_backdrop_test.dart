import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

void main() {
  for (final appearance in [
    AppAppearance.light,
    AppAppearance.sepia,
    AppAppearance.amoled,
  ]) {
    for (final width in [390.0, 844.0]) {
      for (final inset in [0, 24]) {
        testWidgets(
          'header masks upper gutter and confines fade at $appearance/$width/inset=$inset',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            tester.view.padding = FakeViewPadding(top: inset.toDouble());
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final theme = InkoraTheme.forAppearance(appearance);
            const boundary = Key('backdrop-capture');
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: theme,
                  home: const Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: InkScreenHeader(
                      fadeBehind: true,
                      title: SizedBox.shrink(),
                    ),
                    body: ColoredBox(
                      color: Color(0xffff0000),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final rgba = await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
                  .toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final points = <Color>[];
              for (final y in [
                2,
                inset + 7,
                inset + 16,
                inset + 40,
                inset + 62,
                inset + 65,
                inset + 80,
              ]) {
                final i = (y * image.width + 2) * 4;
                points.add(
                  Color.fromARGB(
                    bytes.getUint8(i + 3),
                    bytes.getUint8(i),
                    bytes.getUint8(i + 1),
                    bytes.getUint8(i + 2),
                  ),
                );
              }
              image.dispose();
              return points;
            });
            expect(rgba![0], theme.scaffoldBackgroundColor);
            expect(rgba[1], theme.scaffoldBackgroundColor);
            expect(
              rgba[5],
              const Color(0xffff0000),
              reason: 'The fade ends with the topbar fill, not below it',
            );
            expect(rgba[6], const Color(0xffff0000));
            int distance(Color color) =>
                (color.toARGB32() & 255) +
                ((color.toARGB32() >> 8) & 255) +
                (255 - ((color.toARGB32() >> 16) & 255));
            expect(distance(rgba[2]), greaterThan(distance(rgba[3])));
            expect(distance(rgba[3]), greaterThan(distance(rgba[4])));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
