import 'package:inkora/reader/domain/gesture_zones.dart';
import 'package:inkora/reader/presentation/reader_settings_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_visuals.dart' show chooseSetupMode;

/// Choose through the actual dropdown route, including offscreen options.
Future<void> chooseReaderPreference(WidgetTester tester, String key) async {
  if (!key.startsWith('reader-choice-')) {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    return;
  }
  if (key.startsWith('reader-choice-mode-')) {
    await chooseSetupMode(tester, key.substring('reader-choice-mode-'.length));
    return;
  }
  if (key.startsWith('reader-choice-scope-')) {
    await tester.tap(find.byKey(const Key('reader-settings-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
  } else {
    final option = find.byKey(Key(key), skipOffstage: false).first;
    final selector = find
        .ancestor(
          of: option,
          matching: find.byType(
            DropdownButtonFormField<String>,
            skipOffstage: false,
          ),
        )
        .first;
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final target = find
        .ancestor(of: find.byKey(Key(key)).last, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseGesturePreset(WidgetTester tester, String preset) async {
  final selector = find.byType(DropdownButtonFormField<GesturePreset>);
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('gesture-preset-$preset')).last;
  final target = find
      .ancestor(of: option, matching: find.byType(InkWell))
      .first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String selectedReaderPreference(WidgetTester tester, String id) => tester
    .widget<ReaderChoiceGroup>(
      find.byWidgetPredicate((w) => w is ReaderChoiceGroup && w.id == id),
    )
    .selected;
