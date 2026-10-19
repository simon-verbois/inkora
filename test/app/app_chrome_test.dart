import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../support/ui_harness.dart';

void main() {
  testWidgets('search retains library selection and its filter/view controls', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    await tester.tap(find.byKey(const Key('catalogue-search-toggle')));
    await tester.pumpAndSettle();
    final search = find.byType(CatalogueScreen);
    expect(
      find.descendant(
        of: search,
        matching: find.byKey(const Key('catalogue-filters')),
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
    await tester.enterText(field, 'Moonlit');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: search, matching: find.text('Moonlit District')),
      findsNothing,
    );
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
      await tester.tap(find.byKey(const Key('catalogue-search-toggle')));
      await tester.pumpAndSettle();
      final search = find.byType(CatalogueScreen);
      final field = find.byKey(const Key('catalogue-search')).last;
      final grid = find.descendant(
        of: search,
        matching: find.byType(CatalogueGrid),
      );
      await tester.enterText(field, 'A');
      await tester.pump();
      final before = tester.widget<CatalogueGrid>(grid);
      for (final term in ['At', 'Atl', 'Atlas']) {
        await tester.enterText(field, term);
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.widget<CatalogueGrid>(grid), same(before));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final after = tester.widget<CatalogueGrid>(grid);
      expect(after, isNot(same(before)));
      await tester.enterText(field, ' Atlas ');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tester.widget<CatalogueGrid>(grid), same(after));
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'opacity drafts write once on release and keep MaterialApp retained',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      harness.container.read(routerProvider).go('/settings/appearance');
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final slider = tester.widget<Slider>(
        find.byKey(const Key('panel-opacity')),
      );
      final store = UiPreferencesStore(harness.database);
      final emissions = <double>[];
      final subscription = store.watch().listen(
        (p) => emissions.add(p.panelOpacity),
      );
      addTearDown(subscription.cancel);
      await tester.runAsync(() async {
        await store.watch().first;
      });
      slider.onChanged!(.94);
      slider.onChanged!(.90);
      slider.onChanged!(.88);
      await tester.pump();
      expect(
        (await tester.runAsync(() => store.watch().first))!.panelOpacity,
        .94,
      );
      slider.onChangeEnd!(.88);
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => store.watch().first))!.panelOpacity,
        .88,
      );
      expect(emissions, [.94, .88]);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
      final panel = tester.widget<InkSurface>(
        find.byKey(const Key('floating-navigation-panel')),
      );
      expect(panel.opacity, .88);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('floating-navigation-setting')),
      );
      toggle.onChanged!(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('floating-navigation-panel')), findsNothing);
      expect(
        (await tester.runAsync(() => store.watch().first))!.floatingNavigation,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'reopened setup can exit without changing its completion or preferences',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(panelOpacity: .9),
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
      expect(saved.panelOpacity, .9);
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
