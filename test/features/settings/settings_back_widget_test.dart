import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_workspace.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';
import 'package:inkora/features/connection/presentation/connection_screen.dart';
import 'package:inkora/features/settings/presentation/servers_screen.dart';

import '../../app/home_navigation_widget_test.dart' show backEvent;
import '../../support/ui_harness.dart';

void main() {
  for (final wide in [false, true]) {
    for (final method in ['button', 'system', 'gesture']) {
      testWidgets('settings category Back: wide=$wide/$method', (tester) async {
        tester.view.physicalSize = wide
            ? const Size(1280, 800)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester, resumeEntries: const []);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings');
        await tester.pumpAndSettle();
        if (wide) {
          await tester.tap(find.byKey(const Key('settings-category-language')));
        } else {
          router.push<void>('/settings/language');
        }
        await tester.pumpAndSettle();
        final workspace = tester.state(find.byType(SettingsWorkspace));
        expect(
          find.byType(SettingsScreen, skipOffstage: false),
          findsNWidgets(wide ? 1 : 2),
        );
        if (method == 'button') {
          if (wide) {
            await tester.scrollUntilVisible(
              find.byKey(const Key('settings-sidebar-back')),
              -180,
              scrollable: find
                  .descendant(
                    of: find.byKey(const Key('settings-sidebar')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          await tester.tap(
            wide
                ? find.byKey(const Key('settings-sidebar-back'))
                : find.byType(BackButton),
          );
        } else if (method == 'system') {
          await tester.binding.handlePopRoute();
        } else {
          final bounds = tester.getRect(find.byType(SettingsWorkspace));
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          expect(tester.getRect(find.byType(SettingsWorkspace)), bounds);
          await backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(
            router.routerDelegate.currentConfiguration.last.matchedLocation,
            '/settings/language',
          );
          expect(tester.state(find.byType(SettingsWorkspace)), same(workspace));
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await backEvent(tester, 'commitBackGesture');
        }
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          wide ? '/' : '/settings',
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'nested server Back stays in settings (reduced=$reduceMotion)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(reduceMotion: reduceMotion),
          resumeEntries: const [],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/settings/servers/add');
        await tester.pumpAndSettle();
        expect(find.byType(ConnectionScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/settings/servers',
        );
        expect(find.byType(ServersScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }

  testWidgets(
    'default servers selection keeps its color during predictive Back',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(appearance: AppAppearance.mint),
        resumeEntries: const [],
      );
      addTearDown(() => harness.close(tester));
      const captureKey = Key('settings-back-capture');
      await harness.mount(tester, captureKey: captureKey);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final tile = find.byKey(const Key('settings-category-servers'));
      final bounds = tester.getRect(tile);
      final point = Offset(bounds.right - 12, bounds.center.dy);
      Future<Uint8List> sample() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        final result = Uint8List.fromList(data.buffer.asUint8List(offset, 4));
        image.dispose();
        return result;
      }

      final expected = Theme.of(tester.element(tile))
          .colorScheme
          .secondaryContainer;
      final rgba = [
        (expected.toARGB32() >> 16) & 255,
        (expected.toARGB32() >> 8) & 255,
        expected.toARGB32() & 255,
        255,
      ];
      expect(await tester.runAsync(sample), rgba);
      expect(await backEvent(tester, 'startBackGesture'), isTrue);
      await backEvent(tester, 'updateBackGestureProgress');
      await tester.pump();
      expect(await tester.runAsync(sample), rgba);
      await backEvent(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(await tester.runAsync(sample), rgba);
      expect(await backEvent(tester, 'startBackGesture'), isTrue);
      await backEvent(tester, 'updateBackGestureProgress');
      await tester.pump();
      expect(await tester.runAsync(sample), rgba);
      await backEvent(tester, 'commitBackGesture');
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
      await harness.close(tester);
    },
  );
}
