import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/domain/ebook_settings.dart';
import 'package:inkora/reader/presentation/ebook_margins_dialog.dart';

import '../test/features/library/catalogue_detail_widget_test.dart' show seed;
import '../test/support/ui_harness.dart';
import 'support/ui_fixture_binding.dart';

void main() {
  UiFixtureIntegrationBinding().shouldPropagateDevicePointerEvents = true;
  testWidgets('tablet visual fixtures and real Android series back gesture', (
    tester,
  ) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(locale: 'fr'),
    );
    addTearDown(() => harness.close(tester));
    await seed(harness, tester);
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    router.push('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    debugPrint('READING_COMFORT_CAPTURE_READY: series');
    await Future<void>.delayed(const Duration(seconds: 5));
    debugPrint('READING_COMFORT_EDGE_READY');
    await Future<void>.delayed(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    router.push('/settings/quality');
    await tester.pumpAndSettle();
    debugPrint('READING_COMFORT_CAPTURE_READY: quality');
    await Future<void>.delayed(const Duration(seconds: 5));
    final context = tester.element(find.byType(Scaffold).last);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const EbookMarginsDialog(settings: EbookSettings()),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('READING_COMFORT_CAPTURE_READY: margins');
    await Future<void>.delayed(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
