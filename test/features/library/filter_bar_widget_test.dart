import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/discovery_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale, locale) in [
    (const Size(390, 844), 1.0, 'en'),
    (const Size(390, 844), 2.0, 'en'),
    (const Size(390, 844), 2.0, 'fr'),
    (const Size(390, 844), 2.0, 'de'),
    (const Size(390, 844), 2.0, 'pl'),
    (const Size(800, 1280), 1.0, 'en'),
    (const Size(1280, 800), 1.0, 'en'),
  ]) {
    testWidgets(
      'filter bar chips, sort label/check and filter badge at $size/$scale/$locale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale),
          catalogue: [
            entry('library-a', kind: CatalogueKind.library),
            series(
              'Adventure series',
              library: 'library-a',
              genres: ['Adventure'],
            ),
            series('Fantasy series', library: 'library-a', genres: ['Fantasy']),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        final bar = find.byType(InkFilterBar);
        String tr(String text) => AppStrings.of(tester.element(bar)).text(text);
        InkFilterChip chip(String key) =>
            tester.widget<InkFilterChip>(find.byKey(ValueKey(key)));
        Future<void> tapVisible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        for (final key in [
          'reading-filter-any',
          'reading-filter-unread',
          'reading-filter-inProgress',
          'reading-filter-completed',
          'reading-filter-downloaded',
          'catalogue-sort',
          'catalogue-filters',
          'catalogue-view',
          'library-selector',
        ]) {
          expect(
            tester.getSize(find.byKey(ValueKey(key))).height,
            greaterThanOrEqualTo(48),
            reason: '$key at $size/$scale/$locale',
          );
        }
        final topSearch = find.byKey(const Key('open-search'));
        expect(find.descendant(of: bar, matching: topSearch), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('home-header')),
            matching: topSearch,
          ),
          findsOneWidget,
        );

        // Exclusive reading states, then the independent Downloaded toggle.
        expect(chip('reading-filter-any').selected, isTrue);
        // Fitting quick filters center on the whole toolbar, even though
        // its selector and trailing action groups have different widths.
        final quickRow = find.byKey(const Key('catalogue-chips'));
        final quickScroll = tester.state<ScrollableState>(
          find.descendant(of: quickRow, matching: find.byType(Scrollable)),
        );
        if (quickScroll.position.maxScrollExtent == 0) {
          final first = tester.getRect(
            find.byKey(const ValueKey('reading-filter-any')),
          );
          final last = tester.getRect(
            find.byKey(const ValueKey('reading-filter-downloaded')),
          );
          final toolsRow = find
              .descendant(of: bar, matching: find.byType(Row))
              .first;
          expect(
            (first.left + last.right) / 2,
            closeTo(tester.getCenter(toolsRow).dx, 1),
          );
        }
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reading-filter-any')),
            matching: find.text(tr('All')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reading-filter-unread')),
            matching: find.text(tr('Unread')),
          ),
          findsNothing,
        );

        // The slimmer surface retains its full target, including the padding
        // just above the painted icon. Neighboring targets must not steal it.
        final unread = find.byKey(const ValueKey('reading-filter-unread'));
        await tester.ensureVisible(unread);
        await tester.pumpAndSettle();
        final unreadBounds = tester.getRect(unread);
        await tester.tapAt(
          Offset(unreadBounds.center.dx, unreadBounds.top + 1),
        );
        await tester.pumpAndSettle();
        expect(chip('reading-filter-unread').selected, isTrue);
        expect(chip('reading-filter-any').selected, isFalse);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reading-filter-unread')),
            matching: find.text(tr('Unread')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reading-filter-any')),
            matching: find.text(tr('All')),
          ),
          findsNothing,
        );

        await tapVisible(
          find.byKey(const ValueKey('reading-filter-downloaded')),
        );
        expect(chip('reading-filter-downloaded').selected, isTrue);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reading-filter-downloaded')),
            matching: find.text(tr('Downloaded')),
          ),
          findsOneWidget,
        );

        expect(chip('reading-filter-unread').selected, isTrue);
        await tapVisible(
          find.byKey(const ValueKey('reading-filter-downloaded')),
        );
        await tapVisible(find.byKey(const ValueKey('reading-filter-any')));

        // The sort button names the active order; its menu checks it.
        final sort = find.byKey(const Key('catalogue-sort'));
        final sortLabel = size.width >= 600 || scale <= 1.5;
        expect(
          find.descendant(of: sort, matching: find.text(tr('A–Z'))),
          sortLabel ? findsOneWidget : findsNothing,
        );
        await tapVisible(sort);
        final checked = tester
            .widgetList<CheckedPopupMenuItem<CatalogueSort>>(
              find.byType(CheckedPopupMenuItem<CatalogueSort>),
            )
            .where((item) => item.checked)
            .toList();
        expect(checked, hasLength(1));
        expect(checked.single.value, CatalogueSort.title);
        await tester.tap(find.text(tr('Recently updated')).last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: sort, matching: find.text(tr('Updated'))),
          sortLabel ? findsOneWidget : findsNothing,
        );

        // Advanced filters show an active-count badge.
        final filters = find.byKey(const Key('catalogue-filters'));
        expect(
          find.descendant(
            of: filters,
            matching: find.byKey(const Key('filter-count')),
          ),
          findsNothing,
        );
        await tapVisible(filters);
        await tapVisible(find.byKey(const ValueKey('filter-genres-Adventure')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(
          find.text(tr('Show results ({0})').replaceFirst('{0}', '1')),
          findsOneWidget,
        );
        await tapVisible(find.byKey(const Key('filters-apply')));
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: filters,
                  matching: find.byKey(const Key('filter-count')),
                ),
              )
              .data,
          '1',
        );
        expect(find.text('Adventure series'), findsWidgets);
        expect(find.text('Fantasy series'), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
