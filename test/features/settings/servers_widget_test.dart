import 'package:inkora/features/library/presentation/volume_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/settings/presentation/servers_screen.dart';
import 'package:inkora/features/connection/presentation/connection_screen.dart';

import '../../support/ui_harness.dart';

void main() {
  testWidgets('classic settings drill into pages and add/switch a saved server', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('theme-dark')), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    await tester.tap(find.text('Servers and account'));
    await tester.pumpAndSettle();
    expect(find.text('Saved servers'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-server')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ServersScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(const Key('add-server')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-server')));
    await tester.pumpAndSettle();
    final original = harness.container.read(sessionProvider).session!.accountId;
    await tester.enterText(
      find.byKey(const Key('server-url')),
      'https://second.test/komga',
    );
    await tester.enterText(find.byKey(const Key('secret')), 'second-fixture');
    await tester.ensureVisible(find.text('Save server'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConnectionScreen>(find.byType(ConnectionScreen)).addServer,
      isTrue,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save server'));
      await tester.tap(find.text('Save server'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    for (var frame = 0; frame < 6; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();
    expect(find.text('Saved servers'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('second.test'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(ServersScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('second.test'), findsOneWidget);
    expect(
      harness.container.read(sessionProvider).session!.accountId,
      original,
    );
    expect(
      await harness.container.read(sessionStoreProvider).savedSessions(),
      hasLength(2),
    );
    await tester.ensureVisible(find.text('second.test'));
    await tester.runAsync(() async {
      await tester.tap(find.text('second.test'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    // A newly mounted catalogue starts real asynchronous SQLite subscriptions.
    // Yield to their completion instead of advancing only the spinner's clock.
    for (var turn = 0; turn < 5; turn++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
    expect(
      harness.container.read(sessionProvider).session!.endpoint.uri.host,
      'second.test',
    );
    expect(
      harness.container
          .read(routerProvider)
          .routeInformationProvider
          .value
          .uri
          .path,
      '/',
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets('Libraries root stays on series, with volumes inside a series', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    harness.container.read(routerProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.text('Books'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(VolumeListTile),
        matching: find.text('Moonlit District · Volume 3'),
      ),
      findsNothing,
    );
    final cards = tester.widgetList<CatalogueCard>(find.byType(CatalogueCard));
    expect(cards, isNotEmpty);
    expect(
      cards.every((card) => card.item.kind == CatalogueKind.series),
      isTrue,
    );
    await tester.tap(find.text('Moonlit District'));
    await tester.pumpAndSettle();
    expect(find.text('Browse books'), findsNothing);
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(VolumeListTile),
        matching: find.text('Moonlit District · Volume 3'),
      ),
      250,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(VolumeListTile),
        matching: find.text('Moonlit District · Volume 3'),
      ),
      findsOneWidget,
    );
    expect(find.text('Atlas Nine · Volume 1'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
