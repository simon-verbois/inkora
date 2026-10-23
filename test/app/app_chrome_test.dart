import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/app/widgets/ink_surface.dart';

import '../support/ui_harness.dart';

void main() {
  testWidgets('search retains library selection and its filter/view controls', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final search = find.byType(CatalogueScreen);
    expect(
      find.descendant(
        of: search,
        matching: find.byKey(const Key('catalogue-pinned-tools')),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: search,
        matching: find.byKey(const Key('library-selector')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Graphic novels').last);
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('catalogue-search')).last;
    if (find
        .byKey(const Key('open-search'))
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-search')).hitTestable().last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(field, 'Moonlit');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: search, matching: find.text('Moonlit District')),
      findsNothing,
    );
    if (find
        .byKey(const Key('open-search'))
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-search')).hitTestable().last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(field, 'Atlas');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: search, matching: find.text('Atlas Nine')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'typing coalesces grid rebuilds and ignores an unchanged trimmed term',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final search = find.byType(CatalogueScreen);
      final field = find.byKey(const Key('catalogue-search')).last;
      final grid = find.descendant(
        of: search,
        matching: find.byType(CatalogueGrid),
      );
      // Not even the first keystroke rebuilds the screen: the search field
      // owns its clear button (no empty/non-empty setState on the screen).
      final before = tester.widget<CatalogueGrid>(grid);
      for (final term in ['A', 'At', 'Atl', 'Atlas']) {
        if (find
            .byKey(const Key('open-search'))
            .hitTestable()
            .evaluate()
            .isNotEmpty) {
          await tester.tap(
            find.byKey(const Key('open-search')).hitTestable().last,
          );
          await tester.pumpAndSettle();
        }
        await tester.enterText(field, term);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.widget<CatalogueGrid>(grid), same(before));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final after = tester.widget<CatalogueGrid>(grid);
      expect(after, isNot(same(before)));
      if (find
          .byKey(const Key('open-search'))
          .hitTestable()
          .evaluate()
          .isNotEmpty) {
        await tester.tap(
          find.byKey(const Key('open-search')).hitTestable().last,
        );
        await tester.pumpAndSettle();
      }
      await tester.enterText(field, ' Atlas ');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tester.widget<CatalogueGrid>(grid), same(after));
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'Home counts save independently and opacity has a fixed surface',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      harness.container.read(routerProvider).go('/settings/appearance');
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final store = UiPreferencesStore(harness.database);
      SegmentedButton<int> selector(String name) =>
          tester.widget<SegmentedButton<int>>(
            find.descendant(
              of: find.byKey(Key(name)),
              matching: find.byType(SegmentedButton<int>),
            ),
          );
      selector('home-portrait-columns').onSelectionChanged!({4});
      await tester.pumpAndSettle();
      var saved = (await tester.runAsync(() => store.watch().first))!;
      expect(saved.homePortraitColumns, 4);
      expect(saved.homeLandscapeColumns, 6);
      selector('home-landscape-columns').onSelectionChanged!({7});
      await tester.pumpAndSettle();
      saved = (await tester.runAsync(() => store.watch().first))!;
      expect(saved.homePortraitColumns, 4);
      expect(saved.homeLandscapeColumns, 7);
      expect(find.byKey(const Key('panel-opacity')), findsNothing);
      for (final element in find.byType(InkOverlaySurface).evaluate()) {
        final surface = tester.widget<InkSurface>(
          find
              .descendant(
                of: find.byElementPredicate((e) => e == element),
                matching: find.byType(InkSurface),
              )
              .first,
        );
        expect(surface.opacity, .96);
      }
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'reopened setup can exit without changing its completion or preferences',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(
          homePortraitColumns: 4,
          homeLandscapeColumns: 5,
        ),
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/setup?edit=true');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      final saved = await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      );
      expect(saved!.setupCompleted, isTrue);
      expect(saved.homePortraitColumns, 4);
      expect(saved.homeLandscapeColumns, 5);
      router.go('/setup?edit=true');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );
}
