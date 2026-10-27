import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/presentation/series_header.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/servers_screen.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../test/features/library/series_detail_widget_test.dart'
    show seedSeries;
import '../test/support/catalogue_artwork.dart';
import '../test/support/connection_fakes.dart';
import '../test/support/reader_widget_support.dart';
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('tablet settings and series follow-up with isolated data', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    final directory = await Directory.systemTemp.createTemp(
      'inkora-series-ui-',
    );
    final cover = await demonstrationCover(1);
    final adapter = FixtureAdapter(
      (_) => ResponseBody.fromBytes(
        cover,
        200,
        headers: {
          'content-type': ['image/png'],
        },
      ),
    );
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    final covers = CoverRepository(
      client,
      PageNetworkGate(),
      directory,
      savedSession.accountId,
    );
    for (final id in ['series-a', 'v1', 'v2', 'v3', 'v4', 'v5', 'v6']) {
      await covers.load((
        kind: id == 'series-a' ? 'series' : 'book',
        id: id,
        modified: 0,
      ), CancellationController());
    }
    final harness = await UiHarness.create(
      tester,
      covers: covers,
      resumeEntries: const [],
      refreshCatalogue: false,
      preferences: const UiPreferences(
        locale: 'fr',
        appearance: AppAppearance.light,
      ),
    );
    addTearDown(() async {
      await harness.close(tester);
      await covers.flush();
      covers.close();
      client.close();
      await directory.delete(recursive: true);
      await SystemChrome.setPreferredOrientations([]);
    });
    await seedSeries(harness, tester);
    await harness.mount(tester);
    await binding.convertFlutterSurfaceToImage();
    final router = harness.container.read(routerProvider);
    Future<void> capture(String name) async {
      await settleReaderImages(tester);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('tablet-$name');
    }

    router.go('/settings');
    await capture('settings-servers-default');
    expect(find.byType(ServersScreen), findsOneWidget);
    expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
    router.go('/settings/about');
    await tester.pumpAndSettle();
    final support = find.byKey(const Key('about-support'));
    await tester.ensureVisible(support);
    await capture('about-support');
    final supportRect = tester.getRect(support);
    final licensesRect = tester.getRect(
      find.byKey(const Key('about-licenses')),
    );
    expect(supportRect.top, greaterThan(licensesRect.bottom));
    expect(supportRect.center.dx, closeTo(licensesRect.center.dx, 1));

    router.go('/');
    await tester.pumpAndSettle();
    router.push<void>('/catalogue/series/series-a');
    await capture('series-before-scroll');
    expect(find.byType(VolumeTile), findsWidgets);
    expect(find.byType(VolumeRow), findsNothing);
    final pane = find.byKey(const Key('series-about-pane'));
    final backdrop = find.byType(SeriesBackdrop);
    final bounds = tester.getRect(backdrop);
    final calls = adapter.requests.length;
    await tester.drag(pane, const Offset(0, -180));
    await capture('series-after-scroll');
    expect(tester.getRect(backdrop), bounds);
    expect(bounds, tester.getRect(pane));
    expect(adapter.requests.length, calls);

    await tester.tap(find.byKey(const Key('volume-view')));
    await tester.pumpAndSettle();
    final mark = find.byKey(const Key('volume-mark-read-v1'));
    expect(tester.widget<IconButton>(mark).tooltip, 'Marquer comme non lu');
    expect(tester.widget<IconButton>(mark).onPressed, isNotNull);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(mark).tooltip, 'Marquer comme lu');
    await capture('series-marked-unread');
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(mark).tooltip, 'Marquer comme non lu');
    await UiPreferencesStore(harness.database)
        .update((p) => p.copyWith(appearance: AppAppearance.dark));
    await capture('series-dark-after-scroll');

    await UiPreferencesStore(harness.database)
        .update((p) => p.copyWith(appearance: AppAppearance.light));
    await tester.pumpAndSettle();
    final context = tester.element(find.byKey(const Key('series-about-pane')));
    for (var i = 0; i < 5; i++) {
      notifyInk(context, 'Reading status updated: {0}', arguments: ['1 tome']);
    }
    await capture('notification-compact');
    final surface = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    final notification = tester.getRect(surface);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(notification.width, lessThanOrEqualTo(480));
    expect(notification.center.dx, closeTo(window.width / 2, 1));
    expect(find.byTooltip('Fermer').hitTestable(), findsOneWidget);
    await tester.fling(surface, const Offset(-600, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    notifyInk(context, 'Reading status updated: {0}', arguments: ['1 tome']);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    notifyInk(context, 'Reading status updated: {0}', arguments: ['1 tome']);
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    var retries = 0;
    notifyInk(
      context,
      'Unable to save reading progress.',
      actionLabel: 'Retry',
      onAction: () => retries++,
    );
    await capture('notification-retry');
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(retries, 1);
  });
}
