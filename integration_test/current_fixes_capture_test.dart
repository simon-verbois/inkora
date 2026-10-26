import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/ink_home_attachment.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_screen.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../test/support/catalogue_artwork.dart';
import '../test/support/connection_fakes.dart';
import '../test/support/reader_widget_support.dart';
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive
    ..shouldPropagateDevicePointerEvents = true;
  testWidgets('capture the current fixes on phone and tablet Android', (
    tester,
  ) async {
    final tablet =
        tester.view.physicalSize.shortestSide / tester.view.devicePixelRatio >=
        600;
    final prefix = tablet ? 'tablet' : 'phone';
    await SystemChrome.setPreferredOrientations([
      tablet ? DeviceOrientation.landscapeLeft : DeviceOrientation.portraitUp,
    ]);
    final root = await Directory.systemTemp.createTemp('inkora-current-fixes-');
    final artwork = <String, Uint8List>{};
    for (var i = 0; i < demonstrationTitles.length; i++) {
      artwork['demo-$i'] = await demonstrationCover(i);
    }
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((request) {
        final id = request.uri.pathSegments.firstWhere(
          (part) => artwork.containsKey(part),
          orElse: () => 'demo-0',
        );
        return ResponseBody.fromBytes(
          artwork[id]!,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      }),
    );
    final covers = CoverRepository(
      client,
      PageNetworkGate(),
      Directory('${root.path}/covers'),
      savedSession.accountId,
    );
    final harness = await UiHarness.create(
      tester,
      covers: covers,
      resumeEntries: const [],
      preferences: const UiPreferences(
        locale: 'fr',
        appearance: AppAppearance.ocean,
      ),
      catalogue: [
        const CatalogueItem(
          kind: CatalogueKind.library,
          id: 'library-a',
          title: 'Bibliothèque de démonstration',
        ),
        for (var i = 0; i < demonstrationTitles.length; i++)
          CatalogueItem(
            kind: CatalogueKind.series,
            id: 'demo-$i',
            title: demonstrationTitles[i],
            libraryId: 'library-a',
            itemCount: 4 + i,
          ),
      ],
    );
    addTearDown(() async {
      await harness.close(tester);
      await covers.flush();
      covers.close();
      client.close();
      await root.delete(recursive: true);
      await SystemChrome.setPreferredOrientations([]);
    });
    await harness.mount(tester);
    await binding.convertFlutterSurfaceToImage();
    final router = harness.container.read(routerProvider);
    Future<void> capture(String name) async {
      await settleReaderImages(tester);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('$prefix-$name');
    }

    await capture('01-home');
    final scroll = find.descendant(
      of: find.byType(CatalogueScreen),
      matching: find.byType(CustomScrollView),
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        )
        .position;
    position.jumpTo(position.maxScrollExtent);
    await settleReaderImages(tester);
    final groups = find.byType(InkHomeToolGroup);
    final bounds = [
      for (final element in groups.evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    // Device-source input avoids the test binding's painted pointer crosshair
    // while retaining the held pull in the unedited emulator screenshot.
    final drag = TestGesture(
      dispatcher: (event) async {
        binding.handlePointerEventForSource(
          event,
          source: TestBindingEventSource.device,
        );
      },
    );
    await drag.down(Offset(window.width / 2, window.height * .7));
    await drag.moveBy(const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 100));
    expect([
      for (final element in groups.evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ], bounds);
    await binding.takeScreenshot('$prefix-02-home-bottom-pull');
    await drag.up();
    await tester.pumpAndSettle();

    if (!tablet) {
      final selector = find.byKey(const Key('reading-filter-menu'));
      expect(selector.hitTestable(), findsOneWidget);
      await tester.tap(selector);
      await capture('06-quick-filters-open');
      await tester.tap(find.byKey(const Key('reading-menu-unread')));
      await capture('07-quick-filter-unread');
    }

    router.go('/settings');
    await capture('03-settings-default');
    if (tablet) {
      expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-category-language')));
    } else {
      router.push<void>('/settings/language');
    }
    await capture('04-settings-language');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      tablet ? '/' : '/settings',
    );
    if (!tablet) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(router.routeInformationProvider.value.uri.path, '/');

    final manifest = ReaderManifest(
      accountId: savedSession.accountId,
      bookId: 'demo-epub',
      revision: 'capture',
      title: 'The Lantern Keeper',
      libraryId: 'library-a',
      documentType: 'application/epub+zip',
      pages: [PageDimensions(1, 1)],
    );
    unawaited(
      showInkSheet<void>(
        context: tester.element(find.byType(CatalogueScreen)),
        child: ReaderSettingsSheet(
          modal: true,
          store: ReaderStore(harness.database, savedSession.accountId),
          manifest: manifest,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('Tourner les pages au toucher');
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    final toggle = find.ancestor(
      of: label,
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await capture('05-ebook-tap-disabled');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });
}
