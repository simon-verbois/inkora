import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/library/presentation/reading_history_screen.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';
import 'package:inkora/features/settings/presentation/settings_workspace.dart';
import 'package:inkora/offline/presentation/downloads_screen.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../support/ui_harness.dart';
import 'home_navigation_widget_test.dart' show backEvent;

const destinations = [
  (path: 'settings', key: 'open-settings', type: SettingsWorkspace),
  (path: 'downloads', key: 'open-downloads', type: DownloadsScreen),
  (path: 'history', key: 'reading-history-action', type: ReadingHistoryScreen),
];

Future<UiHarness> mount(
  WidgetTester tester,
  Size size, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
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
  return harness;
}

double fade(WidgetTester tester, Finder page) => tester
    .widget<FadeTransition>(
      find.ancestor(of: page, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('header pages share motion and retain Home geometry at $size', (
      tester,
    ) async {
      final harness = await mount(tester, size);
      final router = harness.container.read(routerProvider);
      final home = find.byType(CatalogueScreen, skipOffstage: false);
      final homeState = tester.state(home);
      final homeRect = tester.getRect(home);
      Rect? opening;
      Rect? closing;
      double? openingOpacity;
      double? closingOpacity;
      for (final destination in destinations) {
        await tester.tap(find.byKey(ValueKey(destination.key)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final page = find.byType(destination.type);
        final rect = tester.getRect(page);
        expect(tester.getRect(home), homeRect);
        expect(tester.state(home), same(homeState));
        expect(rect.size, homeRect.size);
        expect(rect.top, homeRect.top);
        expect(rect.left, greaterThan(0));
        expect(rect.left, lessThan(size.width * .04));
        expect(fade(tester, page), inExclusiveRange(0, 1));
        if (opening != null) {
          expect(rect, opening);
          expect(fade(tester, page), openingOpacity);
        }
        opening = rect;
        openingOpacity = fade(tester, page);
        await tester.pumpAndSettle();
        expect(tester.getRect(page), homeRect);
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getRect(home), homeRect);
        expect(tester.getRect(page).top, homeRect.top);
        if (closing != null) {
          expect(tester.getRect(page), closing);
          expect(fade(tester, page), closingOpacity);
        }
        closing = tester.getRect(page);
        closingOpacity = fade(tester, page);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });

    for (final systemMotion in [false, true]) {
      testWidgets('header motion is disabled at $size (system $systemMotion)', (
        tester,
      ) async {
        if (systemMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final harness = await mount(tester, size, reduceMotion: !systemMotion);
        final router = harness.container.read(routerProvider);
        for (final destination in destinations) {
          await tester.tap(find.byKey(ValueKey(destination.key)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
          expect(tester.getTopLeft(find.byType(destination.type)), Offset.zero);
          router.pop();
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      });
    }
  }

  testWidgets(
    'predictive Back keeps the workspace and category still until commit',
    (tester) async {
      final harness = await mount(tester, const Size(1280, 800));
      final router = harness.container.read(routerProvider);
      for (final destination in destinations) {
        await tester.tap(find.byKey(ValueKey(destination.key)));
        await tester.pumpAndSettle();
        final page = find.byType(destination.type);
        final rect = tester.getRect(page);
        expect(await backEvent(tester, 'startBackGesture'), isTrue);
        await backEvent(tester, 'updateBackGestureProgress');
        await tester.pump();
        expect(tester.getRect(page), rect);
        expect(tester.getRect(page).size, rect.size);
        await backEvent(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(tester.getRect(page), rect);
        expect(await backEvent(tester, 'startBackGesture'), isTrue);
        await backEvent(tester, 'updateBackGestureProgress');
        await tester.pump();
        await backEvent(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }

      router.go('/settings/language');
      await tester.pumpAndSettle();
      final workspace = find.byType(SettingsWorkspace);
      final rect = tester.getRect(workspace);
      final category = find.byWidgetPredicate(
        (widget) => widget is SettingsScreen && widget.section == 'language',
      );
      final categoryRect = tester.getRect(category);
      expect(await backEvent(tester, 'startBackGesture'), isTrue);
      await backEvent(tester, 'updateBackGestureProgress');
      await tester.pump();
      expect(tester.getRect(workspace), rect);
      expect(tester.getRect(category), categoryRect);
      await backEvent(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(tester.getRect(category), categoryRect);
      expect(await backEvent(tester, 'startBackGesture'), isTrue);
      await backEvent(tester, 'updateBackGestureProgress');
      await tester.pump();
      await backEvent(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets('settings sidebar keeps its search across category navigation', (
    tester,
  ) async {
    final harness = await mount(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    final workspace = tester.state(find.byType(SettingsWorkspace));
    await tester.tap(find.byKey(const Key('settings-sidebar-search-toggle')));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('settings-sidebar-search'));
    await tester.enterText(search, 'language');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-language')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(SettingsWorkspace)), same(workspace));
    expect(tester.widget<TextField>(search).controller!.text, 'language');
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  for (final edge in [0, 1]) {
    testWidgets(
      'reader Back excludes the covered settings navigators ($edge)',
      (tester) async {
        final harness = await mount(tester, const Size(1280, 800));
        final router = harness.container.read(routerProvider);
        router.go('/settings/language');
        await tester.pumpAndSettle();
        final workspace = find.byType(SettingsWorkspace, skipOffstage: false);
        final original = tester.getRect(workspace);
        router.push<void>('/reader/book-a');
        await tester.pumpAndSettle();
        final reader = find.byType(ReaderScreen);
        expect(reader, findsOneWidget);
        for (final cancel in [true, false]) {
          expect(
            await backEvent(tester, 'startBackGesture', edge: edge),
            isTrue,
          );
          await backEvent(tester, 'updateBackGestureProgress', edge: edge);
          await tester.pump();
          expect(tester.getRect(workspace), original);
          expect(tester.getRect(reader).left, 0);
          await backEvent(
            tester,
            cancel ? 'cancelBackGesture' : 'commitBackGesture',
            edge: edge,
          );
          await tester.pumpAndSettle();
        }
        expect(
          router.routeInformationProvider.value.uri.path,
          '/settings/language',
        );
        expect(reader, findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
