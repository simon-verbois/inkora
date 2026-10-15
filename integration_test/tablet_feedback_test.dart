import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';

import '../test/features/connection/autofill_widget_test.dart' as autofill;
import '../test/features/library/cover_revalidation_test.dart' as covers;
import '../test/support/ui_harness.dart';
import '../test/reader/presentation/library_application_widget_test.dart'
    as library_settings;
import '../test/reader/presentation/paged_profiles_test.dart' as paged;
import '../test/reader/presentation/webtoon_readiness_test.dart' as webtoon;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  autofill.main();
  library_settings.main();
  paged.main();
  webtoon.main();
  covers.main();
  testWidgets(
    'Android navigation retains the catalogue screen through repeated destination changes',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/libraries');
      await tester.pumpAndSettle();
      final catalogue = tester.state(find.byType(CatalogueScreen));
      for (var round = 0; round < 5; round++) {
        for (final location in ['/settings', '/downloads', '/', '/libraries']) {
          router.go(location);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: location);
        }
        router.push<void>('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.state(find.byType(CatalogueScreen)), same(catalogue));
      }
      await harness.close(tester);
    },
  );
}
