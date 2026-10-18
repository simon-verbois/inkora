import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/ui_harness.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    testWidgets(
      'library is one retained home through alias and rapid tabs at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          resumeEntries: [],
          catalogue: [
            for (var i = 0; i < 250; i++)
              entry(
                'series-$i',
                kind: CatalogueKind.series,
                title: 'Series ${i.toString().padLeft(3, '0')}',
              ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        final screen = tester.state(find.byType(CatalogueScreen));
        router.go('/libraries');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.state(find.byType(CatalogueScreen)), same(screen));
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scroll.position.jumpTo(600);
        await tester.pumpAndSettle();
        final offset = scroll.position.pixels;
        router.go('/settings/appearance');
        await tester.pumpAndSettle();
        for (final branch in [
          'libraries',
          'downloads',
          'libraries',
          'downloads',
          'libraries',
        ]) {
          await tester.tap(find.byKey(ValueKey('navigation-$branch')));
          await tester.pump(const Duration(milliseconds: 35));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CatalogueScreen)), same(screen));
        expect(scroll.position.pixels, closeTo(offset, .1));
        await tester.tap(find.byKey(const Key('navigation-settings')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<SettingsScreen>(find.byType(SettingsScreen)).section,
          'appearance',
        );
        expect(find.byKey(const Key('navigation-home')), findsNothing);
        final nav = tester.getRect(
          find.byKey(const Key('navigation-libraries')),
        );
        expect(nav.top, greaterThan(size.height - 100));
        await harness.close(tester);
      },
    );
  }
}
