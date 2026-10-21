import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/library/series_detail_widget_test.dart'
    show openSeries, showVolumes, row;
import '../support/accessibility.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
    (const Size(1280, 800), 2.0),
  ]) {
    testWidgets('series page, grid and selection meet guidelines at '
        '$size/$scale', (tester) async {
      final harness = await openSeries(tester, size: size, textScale: scale);
      final semantics = tester.ensureSemantics();
      await expectAccessibilityGuidelines(tester);
      if (size.width < 840) await showVolumes(tester);
      await expectAccessibilityGuidelines(tester);
      // Volume rows: one combined label, button role, menu as custom actions.
      await tester.ensureVisible(row('v3'));
      await tester.pumpAndSettle();
      final data = semanticsDataOf(
        tester,
        find.descendant(of: row('v3'), matching: find.byType(InkWell)).first,
      );
      expect(data.label, contains('Moonlit District 03'));
      expect(data.label, contains('In progress'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.customSemanticsActionIds, isNotEmpty);
      // Selection mode exposes the selected state of each row.
      await tester.ensureVisible(find.byKey(const Key('volume-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('volume-select')));
      await tester.pumpAndSettle();
      await expectAccessibilityGuidelines(tester);
      await tester.tap(find.byKey(const Key('selection-close')).first);
      await tester.pumpAndSettle();
      if (scale <= 1.5) {
        await tester.ensureVisible(find.byKey(const Key('volume-view')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('volume-view')));
        await tester.pumpAndSettle();
        await expectAccessibilityGuidelines(tester);
      }
      semantics.dispose();
      await harness.close(tester);
    });
  }

  testWidgets('phone tabs announce selection and switch without animation '
      'under reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = await openSeries(tester);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    final about = find.byKey(const Key('series-tab-about'));
    final volumes = find.byKey(const Key('series-tab-volumes'));
    expect(
      semanticsDataOf(tester, about).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      semanticsDataOf(tester, volumes).flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );
    await tester.ensureVisible(volumes);
    await tester.pumpAndSettle();
    await tester.tap(volumes);
    await tester.pump();
    final controller =
        DefaultTabController.maybeOf(tester.element(volumes)) ??
        tester.widget<TabBar>(find.byKey(const Key('series-tabs'))).controller!;
    // No intermediate frames: the indicator is already on Volumes.
    expect(controller.animation!.value, 1);
    expect(controller.indexIsChanging, isFalse);
    await tester.pumpAndSettle();
    expect(
      semanticsDataOf(tester, volumes).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
    await harness.close(tester);
  });
}
