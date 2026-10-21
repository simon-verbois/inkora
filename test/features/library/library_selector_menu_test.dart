import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 844), 2.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets('library popup anchors, selects and cancels at $size/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        resumeEntries: const [],
        catalogue: [
          for (var i = 0; i < 24; i++)
            entry(
              'library-$i',
              kind: CatalogueKind.library,
              title: i == 1
                  ? 'B shelf'
                  : 'Shelf ${i.toString().padLeft(2, '0')}',
            ),
          entry(
            'series-a',
            kind: CatalogueKind.series,
            libraryId: 'library-0',
            title: 'Alpha',
          ),
          entry(
            'series-b',
            kind: CatalogueKind.series,
            libraryId: 'library-1',
            title: 'Beta',
          ),
        ],
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester, textScale: scale);
      final button = find.byKey(const Key('library-selector'));
      final all = find.byKey(const Key('library-choice-all'));
      final second = find.byKey(const ValueKey('library-choice-library-1'));
      Future<void> open() async {
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(all, findsOneWidget);
      }

      await open();
      expect(
        tester.widget<CheckedPopupMenuItem<(String?,)>>(all).checked,
        isTrue,
      );
      // Placement remains beside the button, with a bounded scrollable surface.
      final surface = find
          .ancestor(of: all, matching: find.byType(Material))
          .first;
      final bounds = tester.getRect(surface);
      final anchor = tester.getRect(button);
      expect(bounds.width, lessThanOrEqualTo(320));
      expect(bounds.height, lessThanOrEqualTo(360));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(size.width));
      expect(bounds.top, closeTo(anchor.bottom + 4, 1));
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(all, findsNothing);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      await open();
      expect(
        tester.widget<CheckedPopupMenuItem<(String?,)>>(second).checked,
        isTrue,
      );
      expect(
        tester.widget<CheckedPopupMenuItem<(String?,)>>(all).checked,
        isFalse,
      );
      await tester.tapAt(Offset(size.width - 4, size.height - 4));
      await tester.pumpAndSettle();
      expect(all, findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(all, findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      await open();
      final last = find.byKey(const ValueKey('library-choice-library-23'));
      final menuScroll = find
          .ancestor(of: all, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(last, 180, scrollable: menuScroll);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(all, -180, scrollable: menuScroll);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }
}
