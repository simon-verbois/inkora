import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/offline/presentation/downloads_screen.dart';

import '../support/catalogue_fakes.dart';
import '../support/ui_harness.dart';

Future<Object?> backEvent(
  WidgetTester tester,
  String method, {
  int edge = 0,
}) async {
  final channel = SystemChannels.backGesture;
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [edge == 0 ? 0.0 : 1280.0, 300.0],
            'progress': method == 'updateBackGestureProgress' ? .4 : 0.0,
            'swipeEdge': edge,
          }),
        ),
        null,
      );
  return response == null ? null : channel.codec.decodeEnvelope(response);
}

Future<UiHarness> mount(
  WidgetTester tester,
  Size size, {
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = await UiHarness.create(
    tester,
    resumeEntries: const [],
    catalogue: [
      entry('library-a', kind: CatalogueKind.library),
      for (var i = 0; i < 120; i++)
        entry(
          'series-$i',
          kind: CatalogueKind.series,
          title: 'Series ${i.toString().padLeft(3, '0')}',
        ),
    ],
  );
  addTearDown(() => harness.close(tester));
  await harness.mount(tester, textScale: scale);
  return harness;
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Home header opens destinations and Back returns Home at $size/$scale',
        (tester) async {
          final harness = await mount(tester, size, scale: scale);
          final router = harness.container.read(routerProvider);
          final home = tester.state(find.byType(CatalogueScreen));
          final overflow = find
              .byKey(const Key('home-menu'))
              .evaluate()
              .isNotEmpty;
          final keys = [
            if (overflow)
              'home-menu'
            else ...[
              'open-settings',
              'open-downloads',
              'reading-history-action',
            ],
            'open-search',
          ];
          double last = -1;
          for (final key in keys) {
            final control = find.byKey(ValueKey(key));
            final rect = tester.getRect(control);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThan(last));
            expect(rect.right, lessThanOrEqualTo(size.width));
            last = rect.left;
          }
          expect(
            find.byKey(const Key('floating-navigation-panel')),
            findsNothing,
          );
          for (final destination in ['downloads', 'settings', 'history']) {
            final key = destination == 'history'
                ? 'reading-history-action'
                : 'open-$destination';
            if (overflow) {
              await tester.tap(find.byKey(const Key('home-menu')));
              await tester.pumpAndSettle();
              await tester.tap(
                find.text(switch (destination) {
                  'history' => 'Reading history',
                  'settings' => 'Settings',
                  _ => 'Downloads',
                }),
              );
            } else {
              await tester.tap(find.byKey(ValueKey(key)));
            }
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              '/$destination',
            );
            expect(router.canPop(), isTrue);
            expect(
              find.byKey(const Key('floating-navigation-panel')),
              findsNothing,
            );
            await tester.pageBack();
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, '/');
            expect(tester.state(find.byType(CatalogueScreen)), same(home));
          }
          await tester.tap(find.byKey(const Key('open-search')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('expanded-search')),
            'Series',
          );
          // Search covers the actions. A route opened externally must still
          // retain the query when Home is revealed again.
          expect(find.byKey(const Key('open-downloads')), findsNothing);
          router.push<void>('/downloads');
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byKey(const Key('expanded-search')))
                .controller!
                .text,
            'Series',
          );
          expect(tester.takeException(), isNull);
          await harness.close(tester);
        },
      );
    }
  }

  testWidgets(
    'Home scroll and loaded catalogue survive settings deep links and Back',
    (tester) async {
      final harness = await mount(tester, const Size(1280, 800));
      final router = harness.container.read(routerProvider);
      final screen = tester.state(find.byType(CatalogueScreen));
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      scroll.jumpTo(600);
      await tester.pumpAndSettle();
      final offset = scroll.pixels;
      router.go('/settings/language');
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.state(find.byType(CatalogueScreen)), same(screen));
      expect(scroll.pixels, offset);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  for (final cancelFirst in [false, true]) {
    testWidgets(
      'predictive Back returns Downloads to Home (cancel $cancelFirst)',
      (tester) async {
        final harness = await mount(tester, const Size(1280, 800));
        final router = harness.container.read(routerProvider);
        await tester.tap(find.byKey(const Key('open-downloads')));
        await tester.pumpAndSettle();
        final downloads = find.byType(DownloadsScreen);
        final rect = tester.getRect(downloads);
        if (cancelFirst) {
          expect(await backEvent(tester, 'startBackGesture'), isTrue);
          await backEvent(tester, 'updateBackGestureProgress');
          await tester.pump();
          await backEvent(tester, 'cancelBackGesture');
          await tester.pumpAndSettle();
          expect(tester.getRect(downloads), rect);
        }
        expect(await backEvent(tester, 'startBackGesture'), isTrue);
        await backEvent(tester, 'updateBackGestureProgress');
        await tester.pump();
        expect(tester.getRect(downloads), rect);
        await backEvent(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(downloads, findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
