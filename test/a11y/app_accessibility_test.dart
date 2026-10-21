import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';

import '../support/accessibility.dart';
import '../support/catalogue_fakes.dart';
import '../support/ui_harness.dart';

const _sizes = [
  (Size(390, 844), 1.0),
  (Size(390, 844), 2.0),
  (Size(1280, 800), 1.0),
  (Size(1280, 800), 2.0),
];

Future<UiHarness> mountForDebug(WidgetTester tester, Size size, double scale) =>
    _mount(tester, size, scale);

Future<UiHarness> _mount(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final reading = entry(
    'book-reading',
    title: 'Lantern Road 03',
    seriesId: 'series-a',
    number: 3,
  );
  final harness = await UiHarness.create(
    tester,
    resumeEntries: [
      ResumeEntry(
        item: reading,
        seriesTitle: 'Lantern Road',
        pageIndex: 9,
        pageCount: 20,
        fraction: 0,
      ),
    ],
    catalogue: [
      entry('library-a', kind: CatalogueKind.library),
      entry('series-a', kind: CatalogueKind.series, title: 'Lantern Road'),
      entry('series-b', kind: CatalogueKind.series, title: 'Atlas Nine'),
      reading,
    ],
  );
  addTearDown(() => harness.close(tester));
  await harness.mount(tester, textScale: scale);
  return harness;
}

void main() {
  for (final (size, scale) in _sizes) {
    testWidgets('Home, catalogue and filters at $size/$scale', (tester) async {
      final harness = await _mount(tester, size, scale);
      await expectAccessibilityGuidelines(tester);
      harness.container.read(routerProvider).go('/catalogue/library');
      await tester.pumpAndSettle();
      await expectAccessibilityGuidelines(tester);
      harness.container.read(routerProvider).go('/catalogue/series');
      await tester.pumpAndSettle();
      await expectAccessibilityGuidelines(tester);
      // Advanced filters sheet: chips, reset and the result footer.
      await tester.tap(find.byTooltip('Filters').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filters-apply')), findsOneWidget);
      await expectAccessibilityGuidelines(tester);
      await harness.close(tester);
    });

    testWidgets('Downloads, history and settings at $size/$scale', (
      tester,
    ) async {
      final harness = await _mount(tester, size, scale);
      final router = harness.container.read(routerProvider);
      for (final path in [
        '/downloads',
        '/history',
        '/settings',
        '/settings/appearance',
        '/settings/reading',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        await expectAccessibilityGuidelines(tester);
      }
      // A settings subpage keeps its title and Back beside the wide pane.
      router.push('/settings/reading-defaults');
      await tester.pumpAndSettle();
      expect(find.text('Global defaults'), findsWidgets);
      expect(find.byType(BackButton), findsOneWidget);
      await expectAccessibilityGuidelines(tester);
      await harness.close(tester);
    });
  }
}
