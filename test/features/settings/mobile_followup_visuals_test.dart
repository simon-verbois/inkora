import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';
import '../../support/onboarding_visuals.dart';
import '../../support/reader_preferences.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'Home separator and permanent actions / sectioned settings at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(loadOnboardingFonts);
        final harness = await UiHarness.create(
          tester,
          preferences: const UiPreferences(
            locale: 'fr',
            appearance: AppAppearance.amoled,
          ),
          resumeEntries: [
            for (var i = 0; i < 3; i++)
              ResumeEntry(
                item: entry(
                  'book-$i',
                  title: 'Un livre à retrouver',
                  seriesId: 'series-$i',
                ),
                pageIndex: 8,
                pageCount: 100,
                fraction: 0,
                seriesTitle: 'Lecture en cours',
              ),
          ],
          catalogue: [
            entry(
              'library-a',
              kind: CatalogueKind.library,
              title: 'Ma bibliothèque',
            ),
            for (var i = 0; i < 80; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Une série à découvrir $i',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        const boundary = Key('mobile-followup-capture');
        await harness.mount(tester, captureKey: boundary);
        final divider = find.byKey(const Key('home-section-separator'));
        expect(divider, findsOneWidget);
        expect(
          tester.getTopLeft(divider).dy -
              tester.getBottomLeft(find.byType(ResumeCarousel)).dy,
          greaterThanOrEqualTo(12),
        );
        expect(find.byKey(const Key('catalogue-tools')), findsNothing);
        final actions = find.byKey(const Key('catalogue-floating-actions'));
        expect(actions, findsOneWidget);
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await captureOnboarding(
          tester,
          find.byKey(boundary),
          'followup-home-$dimensions',
        );
        if (size.height < 500) {
          await Scrollable.ensureVisible(
            tester.element(divider),
            alignment: .4,
          );
          await tester.pumpAndSettle();
          await captureOnboarding(
            tester,
            find.byKey(boundary),
            'followup-home-divider-$dimensions',
          );
        }
        final router = harness.container.read(routerProvider);
        router.push<void>('/settings/quality');
        await tester.pumpAndSettle();
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
        await captureOnboarding(
          tester,
          find.byKey(boundary),
          'followup-quality-$dimensions',
        );
        router.pop();
        await tester.pumpAndSettle();
        router.push<void>('/settings/gestures');
        await tester.pumpAndSettle();
        await chooseGesturePreset(tester, 'custom');
        final surface = find.byKey(const Key('ink-sheet-surface'));
        expect(tester.getSize(surface).width, size.width);
        await captureOnboarding(
          tester,
          find.byKey(boundary),
          'followup-gestures-$dimensions',
        );
        final handle = find.byKey(const Key('ink-sheet-handle'));
        await tester.drag(handle, Offset(0, -size.height));
        await tester.pumpAndSettle();
        expect(tester.getRect(surface).height, greaterThan(size.height * .9));
        await tester.ensureVisible(
          find.byKey(const Key('gesture-custom-save')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('gesture-custom-save')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
