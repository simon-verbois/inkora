import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/features/library/presentation/resume_carousel.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../test/features/library/series_detail_widget_test.dart'
    show seedSeries;
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('requested browsing, series and settings journeys on Android', (
    tester,
  ) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(locale: 'fr'),
      refreshCatalogue: false,
      resumeEntries: const [
        ResumeEntry(
          item: CatalogueItem(
            kind: CatalogueKind.book,
            id: 'v3',
            seriesId: 'series-a',
            title: 'Moonlit District 03',
            number: 3,
          ),
          seriesTitle: 'Moonlit District',
          pageIndex: 10,
          pageCount: 30,
          fraction: 0,
        ),
      ],
    );
    addTearDown(() => harness.close(tester));
    await seedSeries(harness, tester, volumes: 12);
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    expect(find.byKey(const Key('navigation-rail')), findsNothing);
    final homeHeader = find.byKey(const Key('home-header'));
    expect(homeHeader, findsOneWidget);
    expect(
      find.descendant(
        of: homeHeader,
        matching: find.byKey(const Key('open-search')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('catalogue-pinned-tools')),
        matching: find.byKey(const Key('open-search')),
      ),
      findsNothing,
    );
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
      expect(tester.getSize(find.byKey(ValueKey(key))).height, 48, reason: key);
    }
    final historyAction = find.byKey(const Key('reading-history-action'));
    expect(
      find.descendant(of: homeHeader, matching: historyAction),
      findsOneWidget,
    );
    expect(tester.widget(historyAction), isA<IconButton>());
    expect(tester.getSize(historyAction), const Size(48, 48));
    expect(find.text('Historique de lecture'), findsNothing);
    expect(find.byKey(const Key('floating-navigation-panel')), findsNothing);

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.byType(UpNextShelf), findsNothing);
    expect(find.text('View all'), findsNothing);
    await binding.takeScreenshot('home');

    final librarySelector = find.byKey(const Key('library-selector'));
    await tester.tap(librarySelector);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final allLibraries = find.byKey(const Key('library-choice-all'));
    final librarySurface = find
        .ancestor(of: allLibraries, matching: find.byType(Material))
        .first;
    final libraryBounds = tester.getRect(librarySurface);
    final selectorBounds = tester.getRect(librarySelector);
    expect(libraryBounds.width, lessThanOrEqualTo(320));
    expect(libraryBounds.height, lessThanOrEqualTo(360));
    expect(libraryBounds.overlaps(selectorBounds.inflate(12)), true);
    await binding.takeScreenshot('library-menu');
    await tester.tap(find.byKey(const ValueKey('library-choice-library-a')));
    await tester.pumpAndSettle();
    await tester.tap(librarySelector);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<(String?,)>>(
            find.byKey(const ValueKey('library-choice-library-a')),
          )
          .checked,
      true,
    );
    await tester.tap(allLibraries);
    await tester.pumpAndSettle();

    final unreadFilter = find.byKey(const ValueKey('reading-filter-unread'));
    await tester.ensureVisible(unreadFilter);
    await tester.tap(unreadFilter);
    await tester.pumpAndSettle();
    final unreadLabel = AppStrings.of(tester.element(unreadFilter))
        .text('Unread');
    expect(
      find.descendant(of: unreadFilter, matching: find.text(unreadLabel)),
      findsOneWidget,
    );
    await binding.takeScreenshot('quick-filters-active');
    await tester.tap(find.byKey(const ValueKey('reading-filter-any')));
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('open-search')).hitTestable();
    await tester.ensureVisible(search);
    await tester.tap(search);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.view.viewInsets.bottom > 0) break;
    }
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      true,
    );
    expect(
      tester.view.viewInsets.bottom,
      greaterThan(0),
      reason: 'Opening search must show the Android keyboard',
    );
    await binding.takeScreenshot('search');
    final field = tester.widget<TextField>(find.byType(TextField));
    field.focusNode!.unfocus();
    await tester.pumpAndSettle();
    // Closing the expanded search clears it and restores the compact tools.
    await tester.tap(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(historyAction);
    await tester.pumpAndSettle();
    expect(find.byType(ReadingHistoryScreen), findsOneWidget);
    await binding.takeScreenshot('history');
    router.pop();
    await tester.pumpAndSettle();
    router.push<void>('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    await binding.takeScreenshot('series');
    final mark = find.byKey(const Key('detail-mark'));
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);
    await binding.takeScreenshot('series-status');
    Navigator.of(
      tester.element(find.byType(ListTile).last),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-download')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selection-bar')), findsNothing);
    expect(find.byKey(const Key('ink-confirm-accept')), findsOneWidget);
    await binding.takeScreenshot('series-download');
    await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
    await tester.pumpAndSettle();

    for (final section in ['servers', 'transfer']) {
      router.go('/settings/$section');
      await tester.pumpAndSettle();
      await binding.takeScreenshot(section);
    }
    router.go('/downloads');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download-storage')), findsNothing);
    await binding.takeScreenshot('downloads');
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
