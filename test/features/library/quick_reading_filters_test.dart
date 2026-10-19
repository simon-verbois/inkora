import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/presentation/reading_filter_chips.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/ui_harness.dart';

void main() {
  testWidgets(
    'offline quick menu retains metadata and omits redundant availability',
    (tester) async {
      var filters = MetadataFilters.from({CatalogueFacet.genres: 'Adventure'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ReadingFilterChips(
                compact: true,
                offline: true,
                filters: filters,
                onChanged: (value) => update(() => filters = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('reading-quick-filter-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Downloaded only'), findsNothing);
      await tester.tap(
        find
            .ancestor(
              of: find.text('Completed'),
              matching: find.byWidgetPredicate(
                (widget) => widget is CheckedPopupMenuItem<Object?>,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(filters.readingStatus, ReadingStatus.completed);
      expect(filters.values, {CatalogueFacet.genres: 'Adventure'});
      expect(filters.downloadedOnly, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'fr', 'de', 'pl']) {
    testWidgets(
      'compact quick filters select, toggle and cancel at 200% / $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale),
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: 2);
        final control = find.byType(ReadingFilterChips);
        final menu = find.byKey(const Key('reading-quick-filter-menu'));
        String label(String text) =>
            AppStrings.of(tester.element(control)).text(text);
        ReadingFilterChips current() =>
            tester.widget<ReadingFilterChips>(control);
        Future<void> open() async {
          await tester.ensureVisible(menu);
          await tester.tap(menu);
          await tester.pumpAndSettle();
        }

        Future<void> choose(String text) async {
          final option = find
              .ancestor(
                of: find.text(label(text)).last,
                matching: find.byWidgetPredicate(
                  (widget) => widget is CheckedPopupMenuItem<Object?>,
                ),
              )
              .first;
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          await tester.tap(option);
          await tester.pumpAndSettle();
        }

        await open();
        await choose('Unread');
        expect(current().filters.readingStatus, ReadingStatus.unread);
        expect(current().filters.downloadedOnly, isFalse);
        await open();
        expect(
          tester
              .widgetList<CheckedPopupMenuItem<Object?>>(
                find.byWidgetPredicate(
                  (widget) => widget is CheckedPopupMenuItem<Object?>,
                ),
              )
              .where((item) => item.checked),
          hasLength(1),
        );
        await choose('Downloaded only');
        expect(current().filters.readingStatus, ReadingStatus.unread);
        expect(current().filters.downloadedOnly, isTrue);
        final beforeCancel = current().filters;
        await open();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(current().filters, beforeCancel);
        await open();
        await choose('Any');
        expect(current().filters.readingStatus, ReadingStatus.any);
        expect(current().filters.downloadedOnly, isTrue);
        await open();
        await choose('Downloaded only');
        expect(current().filters.isEmpty, isTrue);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
