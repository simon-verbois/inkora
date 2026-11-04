import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/catalogue_filters_sheet.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';
import '../../support/onboarding_visuals.dart';

void main() {
  for (final (size, scale, locale, appearance) in [
    for (final locale in AppStrings.supportedLocales)
      (const Size(390, 844), 2.0, locale.languageCode, AppAppearance.dark),
    (const Size(390, 844), 1.0, 'fr', AppAppearance.dark),
    (const Size(844, 390), 1.0, 'fr', AppAppearance.dark),
    (const Size(800, 1280), 1.0, 'fr', AppAppearance.dark),
    (const Size(1280, 800), 1.0, 'fr', AppAppearance.dark),
    (const Size(390, 844), 1.0, 'fr', AppAppearance.light),
    (const Size(1280, 800), 1.0, 'fr', AppAppearance.forest),
  ]) {
    testWidgets(
      'Home shortcuts remain visible without rebuilding the catalogue at $size/$scale/$locale/${appearance.name}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(bottom: 24);
        tester.view.viewPadding = FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.runAsync(loadOnboardingFonts);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: const [],
          preferences: UiPreferences(locale: locale, appearance: appearance),
          catalogue: [
            entry(
              'library-a',
              kind: CatalogueKind.library,
              title: 'Manga shelf',
            ),
            entry(
              'library-b',
              kind: CatalogueKind.library,
              title: 'Other shelf',
            ),
            for (var i = 0; i < 180; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                libraryId: i.isEven ? 'library-a' : 'library-b',
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        const capture = Key('home-actions-capture');
        await harness.mount(tester, textScale: scale, captureKey: capture);
        final scroll = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        const threshold = 100.0;
        final overlay = find.byKey(const Key('catalogue-floating-actions'));
        expect(find.byKey(const Key('catalogue-tools')), findsNothing);
        expect(overlay, findsOneWidget);
        scroll.jumpTo(threshold + 1);
        await tester.pumpAndSettle();
        final library = find.byKey(const Key('catalogue-floating-library'));
        final filters = find.byKey(const Key('catalogue-floating-filters'));
        Material surface(Finder owner) {
          final panel = find
              .descendant(of: owner, matching: find.byType(InkSurface))
              .first;
          return tester.widget<Material>(
            find.descendant(of: panel, matching: find.byType(Material)).first,
          );
        }

        final header = surface(find.byKey(const Key('home-header')));
        final logo = tester.widget<Text>(
          find.descendant(
            of: find.byType(InkoraWordmark),
            matching: find.byType(Text),
          ),
        );
        for (final action in [library, filters]) {
          final panel = surface(action);
          expect(panel.color, header.color);
          expect(panel.shape, header.shape);
          final border = panel.shape! as RoundedRectangleBorder;
          expect(border.side.width, greaterThan(0));
          expect(border.side.style, BorderStyle.solid);
          final icon = find.descendant(of: action, matching: find.byType(Icon));
          expect(IconTheme.of(tester.element(icon)).color, logo.style!.color);
        }
        expect(library.hitTestable(), findsOneWidget);
        expect(filters.hitTestable(), findsOneWidget);
        expect(tester.getSize(library).shortestSide, greaterThanOrEqualTo(60));
        expect(
          tester.getRect(filters).bottom,
          lessThanOrEqualTo(size.height - 24 - 16),
        );
        expect(tester.getRect(filters).right, greaterThan(size.width - 80));
        final grid = find.byType(CatalogueGrid);
        final gridWidget = grid.evaluate().isNotEmpty
            ? tester.widget(grid)
            : null;
        final remote = harness.repository.remote as FakeCatalogueRemote;
        final calls = remote.calls;
        for (var offset = 2; offset < 22; offset += 2) {
          scroll.jumpTo(threshold + offset);
          await tester.pump();
          if (gridWidget != null) expect(tester.widget(grid), same(gridWidget));
        }
        expect(remote.calls, calls);
        if (locale == 'fr' &&
            scale == 1 &&
            size.width >= 390 &&
            size.height > 400) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'home-topbar-actions-${size.width.toInt()}x${size.height.toInt()}-${appearance.name}-fr',
          );
        }
        await tester.tap(filters);
        await tester.pumpAndSettle();
        expect(find.byType(CatalogueFiltersSheet), findsOneWidget);
        if (locale == 'fr' && scale == 1 && size.width == 390) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'home-direct-filter-${appearance.name}-fr',
          );
        }
        expect(
          find.descendant(
            of: find.byType(CatalogueFiltersSheet),
            matching: find.byKey(const Key('reading-filter-choices')),
          ),
          findsOneWidget,
        );
        if (locale == 'fr' && scale == 1) {
          final unavailable = find.byKey(const Key('filters-unavailable'));
          await tester.ensureVisible(unavailable);
          await tester.tap(unavailable);
          await tester.tap(find.byKey(const Key('filters-apply')));
          await tester.pumpAndSettle();
          expect(overlay, findsOneWidget);
          expect(scroll.pixels, closeTo(threshold + 20, 1));
          await tester.tap(filters);
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(unavailable).value, isTrue);
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          harness.container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );
        expect(scroll.pixels, closeTo(threshold + 20, 1));
        await tester.tap(library);
        await tester.pumpAndSettle();
        if (locale == 'fr' && scale == 1 && size.width == 390) {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'home-topbar-library-${appearance.name}-fr',
          );
        }
        expect(
          find.byKey(const Key('library-choice-library-b')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('library-choice-library-b')));
        await tester.pumpAndSettle();
        expect(scroll.pixels, 0);
        expect(overlay, findsOneWidget);
        expect(find.text('Series 001'), findsOneWidget);
        expect(find.text('Series 000'), findsNothing);
        // Rotation retains selection and permanent controls.
        tester.view.physicalSize = const Size(1280, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await tester.pumpAndSettle();
        expect(overlay, findsOneWidget);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(overlay, findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
