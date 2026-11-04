import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/widgets/ink_screen_header.dart';
import 'package:inkora/app/widgets/ink_divider.dart';
import 'package:inkora/app/widgets/ink_settings_section.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/settings_screen.dart';

import '../../support/ui_harness.dart';
import '../../support/onboarding_visuals.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final (size, scale, reduced) in [
    (const Size(390, 844), 1.0, false),
    (const Size(844, 390), 1.0, false),
    (const Size(768, 1024), 1.0, false),
    (const Size(320, 640), 2.0, true),
  ]) {
    testWidgets('settings search floats on reverse scroll at $size/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(
        tester,
        preferences: UiPreferences(reduceMotion: reduced, locale: 'fr'),
      );
      addTearDown(() => harness.close(tester));
      const capture = Key('polish-capture');
      await harness.mount(tester, textScale: scale, captureKey: capture);
      final router = harness.container.read(routerProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      final screen = find.byType(SettingsScreen);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: screen, matching: find.byType(Scaffold)).first,
      );
      expect(scaffold.extendBodyBehindAppBar, isTrue);
      final search = find.byKey(const Key('settings-search'));
      final scroll = find.byKey(const Key('settings-index-scroll'));
      final row = find.byKey(const ValueKey('settings-entry-servers'));
      final stableRow = tester.widget(row);
      final header = find.byType(InkScreenHeader);
      final headerBounds = tester.getRect(header);
      expect(tester.widget<InkScreenHeader>(header).fadeBehind, isTrue);
      expect(tester.getTopLeft(search).dy, closeTo(headerBounds.bottom + 4, 1));
      final rowWidget = tester.widget<InkSettingsRow>(row);
      expect(rowWidget.trailing, isNull);
      final scrollable = find
          .descendant(of: scroll, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final drag = await tester.startGesture(
        Offset(size.width / 2, size.height * .75),
      );
      for (var i = 0; i < 12; i++) {
        await drag.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(header), headerBounds);
        if (row.evaluate().isNotEmpty) {
          expect(tester.widget(row), same(stableRow));
        }
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsNothing);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final bottom = position.pixels;
      await tester.drag(scroll, const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(position.pixels, lessThan(bottom));
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(search).dy, closeTo(headerBounds.bottom + 4, 1));
      expect(tester.getRect(header), headerBounds);
      await captureOnboarding(
        tester,
        find.byKey(capture),
        'surface-followup-search-${size.width.toInt()}-${scale.toInt()}',
      );
      await tester.enterText(search, AppStrings('fr').text('Language'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-entry-language')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-entry-language')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-entry-language')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SettingsScreen>(find.byType(SettingsScreen).last).section,
        'language',
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('long server identity uses full width at 320 / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      final server = SavedSession(
        endpoint: ServerEndpoint(
          'https://long-library-server.example.test/komga',
        ),
        user: const KomgaUser(
          id: 'long-user',
          email: 'very.long.reader.address@example.test',
          roles: {'USER'},
        ),
        credentials: Credentials.apiKey('fixture'),
      );
      await harness.container.read(sessionStoreProvider).remember(server);
      const capture = Key('server-identity-capture');
      await harness.mount(tester, textScale: scale, captureKey: capture);
      harness.container.read(routerProvider).go('/settings/servers');
      await tester.pumpAndSettle();
      final identity = find.byKey(ValueKey(server.accountId));
      await tester.scrollUntilVisible(identity, 180);
      await tester.pumpAndSettle();
      final actions = find.byKey(
        ValueKey('server-actions-${server.accountId}'),
      );
      expect(
        tester.getTopLeft(actions).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(identity).dy),
      );
      for (final text in [server.endpoint.uri.host, server.user.email]) {
        final label = find.text(text);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.getSize(label).width, greaterThan(180));
      }
      expect(
        find.descendant(of: actions, matching: find.byType(IconButton)),
        findsNWidgets(3),
      );
      await captureOnboarding(
        tester,
        find.byKey(capture),
        'settings-polish-servers-320-${scale.toInt()}',
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets('restarted setup completion always opens Home', (tester) async {
    final harness = await UiHarness.create(
      tester,
      preferences: const UiPreferences(setupStep: 7),
    );
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    router.go('/settings');
    await tester.pumpAndSettle();
    router.go('/settings/about');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('about-guided-setup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about-guided-setup')));
    await tester.pumpAndSettle();
    expect(find.byType(CloseButton), findsNothing);
    for (var i = 0; i < 8; i++) {
      if (i == 0) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('setup-next')),
          180,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('setup-introduction-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.ensureVisible(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
    }
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(CatalogueGrid), findsWidgets);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(
      (await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      ))!.setupCompleted,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'catalogue layout is chosen only in Settings and persists through navigation',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('catalogue-layout'));
      await tester.scrollUntilVisible(field, 300);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show list').last);
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(
        () => UiPreferencesStore(harness.database).watch().first,
      ))!;
      expect(saved.catalogueListView, isTrue);
      expect(UiPreferences.fromJson(saved.toJson()).catalogueListView, isTrue);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(CatalogueGrid), findsNothing);
      await tester.tap(find.byKey(const Key('catalogue-floating-filters')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show grid'), findsNothing);
      expect(find.byTooltip('Show list'), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  testWidgets(
    'all preference categories share gold type and omit the first divider',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      for (final section in [
        'quality',
        'appearance',
        'accessibility',
        'downloads',
        'gestures',
        'language',
        'reading-defaults',
        'servers',
      ]) {
        router.go('/settings/$section');
        await tester.pumpAndSettle();
        final headings = find.byType(InkSettingsHeading);
        for (final element in headings.evaluate()) {
          final widget = element.widget as InkSettingsHeading;
          final heading = find.byWidget(widget);
          final label = tester.widget<LText>(
            find.descendant(of: heading, matching: find.byType(LText)).first,
          );
          expect(label.style, InkSettingsHeading.titleStyleOf(element));
          expect(
            find.descendant(of: heading, matching: find.byType(InkDivider)),
            widget.first ? findsNothing : findsOneWidget,
          );
        }
        if (headings.evaluate().isNotEmpty && section != 'reading-defaults') {
          expect(
            tester.widget<InkSettingsHeading>(headings.first).first,
            isTrue,
            reason: section,
          );
        }
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('Reset to default'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await harness.close(tester);
    },
  );
}
