import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';

import '../support/ui_harness.dart';

void main() {
  for (final appearance in [
    AppAppearance.light,
    AppAppearance.dark,
    AppAppearance.amoled,
  ]) {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      testWidgets(
        'settings transition keeps the page background at $size/${appearance.name}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            preferences: UiPreferences(appearance: appearance),
          );
          addTearDown(() => harness.close(tester));
          const capture = Key('transition-capture');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.container,
              child: const RepaintBoundary(key: capture, child: InkoraApp()),
            ),
          );
          await tester.pumpAndSettle();
          final router = harness.container.read(routerProvider);
          router.go('/settings');
          await tester.pumpAndSettle();
          final pageRect = tester.getRect(find.byType(SettingsScreen));
          final boundaryRect = tester.getRect(find.byKey(capture));
          final sample = Offset(
            pageRect.right - boundaryRect.left - 4,
            pageRect.top - boundaryRect.top + 4,
          );
          final expected =
              (appearance == AppAppearance.light
                      ? InkoraTheme.light()
                      : InkoraTheme.dark(
                          amoled: appearance == AppAppearance.amoled,
                        ))
                  .scaffoldBackgroundColor;
          Future<void> checkBackground(String frame) async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(capture),
            );
            final color = await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              // The top four-pixel gutter stays clear in compact pages and in
              // wide panes without a second AppBar. The old 64px probe now
              // intersects real theme cards while those panes slide in.
              final offset =
                  (sample.dy.floor() * image.width + sample.dx.floor()) * 4;
              final result = Color.fromARGB(
                bytes.getUint8(offset + 3),
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              );
              image.dispose();
              return result;
            });
            final actualArgb = color!.toARGB32();
            final expectedArgb = expected.toARGB32();
            expect(actualArgb >> 24, expectedArgb >> 24, reason: frame);
            // Skia/Impeller can round a flat surface by one 8-bit channel value.
            // The old panel-colored flash differs by at least four in every theme.
            for (final shift in [16, 8, 0]) {
              final difference =
                  (((actualArgb >> shift) & 255) -
                          ((expectedArgb >> shift) & 255))
                      .abs();
              expect(
                difference,
                lessThanOrEqualTo(1),
                reason: '$frame; channel $shift',
              );
            }
          }

          await checkBackground('settings settled');
          for (final section in [
            'appearance',
            'language',
            'library-defaults',
            'servers',
          ]) {
            router.push<void>('/settings/$section');
            await tester.pump();
            for (final delta in [50, 70, 100, 150]) {
              await tester.pump(Duration(milliseconds: delta));
              await checkBackground('$section forward after $delta ms');
            }
            await tester.pumpAndSettle();
            router.pop();
            await tester.pump();
            for (final delta in [50, 70, 100, 150]) {
              await tester.pump(Duration(milliseconds: delta));
              await checkBackground('$section reverse after $delta ms');
            }
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }
}
