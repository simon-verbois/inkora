import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/reading_filter_chips.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (width, scale, locale, _) in [
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
      expect(find.byKey(const Key('reading-filter-menu')), findsNothing);
      final floating = find.byKey(const Key('catalogue-floating-filters'));
      expect(floating.hitTestable(), findsOneWidget);
      await tester.tap(floating);
      await tester.pumpAndSettle();
      final selector = find.byKey(const Key('reading-filter-menu'));
      expect(selector.hitTestable(), findsOneWidget);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      for (final status in ReadingStatus.values) {
        final choice = find.byKey(ValueKey('reading-menu-${status.name}'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(choice.hitTestable(), findsOneWidget);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reading-menu-unread')));
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('reading-menu-any')).evaluate().isNotEmpty) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      tester.view.physicalSize = const Size(1280, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pumpAndSettle();
      final draft = tester
          .widget<ReadingFilterMenu>(find.byType(ReadingFilterMenu))
          .filters;
      expect(draft.readingStatus, ReadingStatus.unread);
      expect(draft.downloadedOnly, isTrue);
      await tester.tap(find.byKey(const Key('filters-apply')));
      await tester.pumpAndSettle();
      await tester.tap(floating);
      await tester.pumpAndSettle();
      final saved = tester
          .widget<ReadingFilterMenu>(find.byType(ReadingFilterMenu))
          .filters;
      expect(saved, draft);
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
