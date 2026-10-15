import 'package:inkora/features/library/presentation/library_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/presentation/reader_gesture_guard.dart';
import 'package:inkora/reader/domain/gesture_zones.dart';

import '../../support/ui_harness.dart';

void main({bool includeLifecycle = true}) {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'reader system back restores its series and the previous page at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/libraries');
        await tester.pumpAndSettle();
        router.push<void>('/catalogue/series/series-a');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('detail-read')));
        await tester.pumpAndSettle();
        expect(find.byType(ReaderScreen), findsOneWidget);
        expect(find.byKey(const Key('navigation-settings')), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ReaderScreen), findsNothing);
        expect(find.byType(CatalogueDetailScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/libraries');
        expect(find.byType(CatalogueDetailScreen), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
  testWidgets(
    'first-run setup follows login and completes with durable configuration',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await tester.runAsync(
        () => UiPreferencesStore(harness.database).save(
          // Keep English assertions independent of the device's system locale.
          const UiPreferences(locale: 'en'),
        ),
      );
      await harness.mount(tester);
      expect(
        harness.container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/setup',
      );
      expect(find.text('Make Inkora yours'), findsOneWidget);
      for (var step = 0; step < 7; step++) {
        await tester.tap(find.byKey(const Key('setup-next')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('setup-next')));
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
      final saved = await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      );
      expect(saved!.setupCompleted, true);
      expect(saved.setupStep, 7);
      await harness.close(tester);
    },
  );
  testWidgets(
    'reserved edges do not deliver reader drags while the central area does',
    (tester) async {
      var drags = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: ReaderGestureGuard(
              zones: const GestureZones(left: 32, right: 32),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (_) => drags++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(4, 200), const Offset(100, 0));
      await tester.pump();
      expect(drags, 0);
      await tester.dragFrom(const Offset(200, 200), const Offset(100, 0));
      await tester.pump();
      expect(drags, greaterThan(0));
    },
  );
  testWidgets('gesture drafts commit on release without rebuilding the app', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/settings/gestures');
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(32);
    slider.onChanged!(40);
    slider.onChanged!(48);
    await tester.pump();
    final store = UiPreferencesStore(harness.database);
    expect(
      (await tester.runAsync(() => store.watch().first))!.gestures.left,
      16,
    );
    tester.widget<Slider>(find.byType(Slider).first).onChangeEnd!(48);
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => store.watch().first))!.gestures.left,
      48,
    );
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
    await harness.close(tester);
  });
  if (includeLifecycle) {
    testWidgets('Home stops polling offstage and in the background', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final dynamic state = tester.state(find.byType(LibraryScreen));
      expect(state.pollingActive, isTrue);
      harness.container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(state.pollingActive, isFalse);
      harness.container.read(routerProvider).go('/');
      await tester.pumpAndSettle();
      expect(state.pollingActive, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(state.pollingActive, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.pollingActive, isTrue);
      await harness.close(tester);
    });
  }
}
