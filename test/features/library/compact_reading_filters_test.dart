import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/reading_filter_chips.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (width, scale, locale, compact) in [
    (320.0, 1.0, 'fr', true),
    (320.0, 2.0, 'fr', true),
    (375.0, 1.0, 'fr', true),
    (390.0, 1.0, 'fr', true),
    for (final locale in languageNames.keys) (390.0, 2.0, locale, true),
    (639.0, 1.0, 'fr', true),
    (640.0, 1.0, 'fr', false),
    (641.0, 1.0, 'fr', false),
    (800.0, 1.0, 'fr', false),
    (1280.0, 1.0, 'fr', false),
  ]) {
    testWidgets('Home quick filters fit $width / $scale / $locale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        resumeEntries: const [],
        preferences: UiPreferences(locale: locale),
        catalogue: [
          for (var i = 0; i < 80; i++)
            entry('series-$i', kind: CatalogueKind.series),
        ],
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester, textScale: scale);
      final selector = find.byKey(const Key('reading-filter-menu'));
      if (!compact) {
        expect(selector, findsNothing);
        expect(find.byKey(const Key('reading-filter-any')), findsOneWidget);
      } else {
        expect(selector.hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('catalogue-chips')), findsNothing);
        final tools = find.byKey(const Key('catalogue-tools-menu'));
        final rect = tester.getRect(selector);
        final group = tester.getRect(
          find.ancestor(of: selector, matching: find.byType(InkHomeToolGroup)),
        );
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.right, lessThanOrEqualTo(tester.getRect(tools).left));
        expect(rect.left, closeTo(group.left + 20, .01));
        expect(tester.getRect(tools).right, closeTo(group.right - 20, .01));
        if (scale == 1) {
          // The short French label must leave free space before the burger.
          expect(rect.width, lessThan(160));
          expect(tester.getRect(tools).left - rect.right, greaterThan(8));
        }
        final scroll = find.descendant(
          of: find.byType(CatalogueScreen),
          matching: find.byType(CustomScrollView),
        );
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        position.jumpTo(300);
        await tester.pumpAndSettle();
        final before = position.pixels;

        Future<void> open() async {
          await tester.tap(selector);
          await tester.pumpAndSettle();
        }

        await open();
        for (final status in ReadingStatus.values) {
          final choice = find.byKey(ValueKey('reading-menu-${status.name}'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(choice.hitTestable(), findsOneWidget);
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reading-menu-any')), findsNothing);
        expect(
          harness.container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          '/',
        );

        for (final status in ReadingStatus.values.reversed) {
          await open();
          await tester.tap(find.byKey(ValueKey('reading-menu-${status.name}')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ReadingFilterMenu>(find.byType(ReadingFilterMenu))
                .filters
                .readingStatus,
            status,
          );
          expect(position.pixels, closeTo(before, 1));
        }
        await open();
        final downloaded = find.byType(CheckboxMenuButton);
        await tester.ensureVisible(downloaded);
        await tester.pumpAndSettle();
        await tester.tap(downloaded);
        await tester.pumpAndSettle();
        final filters = tester
            .widget<ReadingFilterMenu>(find.byType(ReadingFilterMenu))
            .filters;
        expect(filters.downloadedOnly, isTrue);
        expect(filters.readingStatus, ReadingStatus.any);
        expect(
          find.descendant(
            of: selector,
            matching: find.byWidgetPredicate(
              (widget) => widget is Icon && widget.semanticLabel != null,
            ),
          ),
          findsOneWidget,
        );
        // Rotate/resize in place; the same filter owner feeds direct chips.
        tester.view.physicalSize = const Size(1280, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        await tester.pumpAndSettle();
        expect(selector, findsNothing);
        expect(
          tester
              .widget<InkFilterChip>(
                find.byKey(const Key('reading-filter-downloaded')),
              )
              .selected,
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets(
    'compact choices retain metadata and independent download state',
    (tester) async {
      var filters = MetadataFilters.from({
        CatalogueFacet.genres: 'Adventure',
      }, downloadedOnly: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 260,
                child: ReadingFilterMenu(
                  filters: filters,
                  onChanged: (next) => setState(() => filters = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('reading-filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reading-menu-inProgress')));
      await tester.pumpAndSettle();
      expect(filters.values, {CatalogueFacet.genres: 'Adventure'});
      expect(filters.readingStatus, ReadingStatus.inProgress);
      expect(filters.downloadedOnly, isTrue);
      await tester.tap(find.byKey(const Key('reading-filter-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      expect(filters.values, {CatalogueFacet.genres: 'Adventure'});
      expect(filters.readingStatus, ReadingStatus.inProgress);
      expect(filters.downloadedOnly, isFalse);
    },
  );
}
