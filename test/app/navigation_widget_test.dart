import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/inkora_navigation.dart';

void main() {
  for (final language in languageNames.keys) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$language sidebar keeps words whole at $scale text scale', (
        tester,
      ) async {
        var selected = 0;
        final textScaler = TextScaler.linear(scale);
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.light(),
            locale: AppStrings.localeFor(language),
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Row(
                      children: [
                        InkoraNavigation(
                          vertical: true,
                          selectedIndex: selected,
                          onSelect: (value) => setState(() => selected = value),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in ['Home', 'Libraries', 'Downloads', 'Settings']) {
          final label = AppStrings(language).text(key);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason: label,
          );
          expect(paragraph.didExceedMaxLines, false);
        }
        final dynamic state = tester.state(find.byType(InkoraNavigation));
        final measured = state.labelMeasurementCount;
        update(() => selected = 3);
        await tester.pumpAndSettle();
        expect(
          state.labelMeasurementCount,
          measured,
          reason: 'Selection does not remeasure unchanged localized labels',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final vertical in [false, true]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'whole destination ripples then clears: $vertical/$reducedMotion',
        (tester) async {
          const captureKey = Key('navigation-capture');
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: InkoraTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reducedMotion),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: captureKey,
                      child: SizedBox(
                        width: vertical ? 112 : 390,
                        height: vertical ? 400 : null,
                        child: InkoraNavigation(
                          vertical: vertical,
                          selectedIndex: selected,
                          onSelect: (value) => selected = value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InkWell), findsNWidgets(4));
          expect(find.text('Favorites'), findsNothing);
          Future<Uint8List> pixels() async => (await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(captureKey),
            );
            final capture = await boundary.toImage(pixelRatio: 1);
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            capture.dispose();
            return bytes!.buffer.asUint8List();
          }))!;
          final before = await pixels();
          final button = find.byKey(const Key('navigation-home'));
          final bounds = tester.getRect(button);
          final icon = find.descendant(of: button, matching: find.byType(Icon));
          expect(bounds.contains(tester.getCenter(icon)), isTrue);
          expect(bounds.contains(tester.getCenter(find.text('Home'))), isTrue);
          expect(bounds.height, greaterThanOrEqualTo(48));
          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Home')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final during = await pixels();
          expect(listEquals(before, during), reducedMotion);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(
            await pixels(),
            orderedEquals(before),
            reason: 'No persistent selection or pressed background',
          );
          await tester.tap(find.text('Libraries'));
          await tester.pumpAndSettle();
          expect(selected, 1);
          await tester.tap(find.text('Downloads'));
          await tester.pumpAndSettle();
          expect(selected, 2);
          final settingsIcon = find.descendant(
            of: find.byKey(const Key('navigation-settings')),
            matching: find.byType(Icon),
          );
          await tester.tap(settingsIcon);
          await tester.pumpAndSettle();
          expect(selected, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
