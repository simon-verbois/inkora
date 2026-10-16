import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/widgets/inkora_navigation.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/library/presentation/book_cover.dart';
import 'package:inkora/features/library/presentation/catalogue_card.dart';
import 'package:inkora/features/library/presentation/catalogue_detail_screen.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';

import '../support/ui_harness.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    for (final appearance in [
      AppAppearance.light,
      AppAppearance.dark,
      AppAppearance.amoled,
    ]) {
      testWidgets(
        'all destinations and settings at $size in ${appearance.name}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = await UiHarness.create(
            tester,
            preferences: UiPreferences(appearance: appearance),
          );
          addTearDown(() => harness.close(tester));
          await harness.mount(tester);
          expect(find.text('Continue reading'), findsOneWidget);
          expect(find.byTooltip('Refresh catalogue'), findsNothing);
          expect(find.byTooltip('Search catalogue'), findsOneWidget);
          expect(find.byIcon(Icons.shield_outlined), findsNothing);
          final router = harness.container.read(routerProvider);
          for (final location in [
            '/libraries',
            '/settings',
            '/downloads',
            '/settings/appearance',
            '/settings/downloads',
            '/settings/accessibility',
            '/settings/quality',
            '/settings/reading',
            '/settings/reading-defaults',
            '/settings/about',
            '/settings/account',
            '/catalogue/series/series-a',
            '/catalogue/book/book-a',
          ]) {
            router.go(location);
            await tester.pumpAndSettle();
            if (!location.startsWith('/catalogue/book/')) {
              expect(
                find.byTooltip('Search catalogue'),
                location == '/catalogue/series/series-a'
                    ? findsNothing
                    : findsOneWidget,
                reason: location,
              );
            }
            expect(tester.takeException(), isNull, reason: location);
          }
          router.go('/libraries');
          await tester.pumpAndSettle();
          expect(find.byTooltip('Search catalogue'), findsOneWidget);
          expect(find.text('Favorites'), findsNothing);
          expect(find.byKey(const Key('navigation-downloads')), findsOneWidget);
          expect(find.byKey(const Key('navigation-settings')), findsOneWidget);
          expect(
            tester
                .widget<InkoraNavigation>(find.byType(InkoraNavigation))
                .vertical,
            size.width >= InkoraLayout.railBreakpoint,
          );
          await harness.close(tester);
        },
      );
    }
  }

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('shelf covers lead directly to titles and details at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final card = find
          .byWidgetPredicate(
            (widget) => widget is CatalogueCard && widget.item.id == 'series-a',
          )
          .first;
      final cover = find.descendant(of: card, matching: find.byType(BookCover));
      final title = find.descendant(
        of: card,
        matching: find.text('Moonlit District'),
      );
      final gap = tester.getTopLeft(title).dy - tester.getBottomLeft(cover).dy;
      expect(gap, inInclusiveRange(0, 6));
      expect(tester.getSize(cover).width, tester.getSize(card).width);
      await tester.tap(cover);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CatalogueDetailScreen>(find.byType(CatalogueDetailScreen))
            .id,
        'series-a',
      );
      expect(find.byTooltip('Search catalogue'), findsNothing);
      harness.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Search catalogue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets('publication sheet blocks navigation behind its modal barrier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    final router = harness.container.read(routerProvider);
    router.go('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    // The shared sheet must cover both branch content and shell navigation.
    final context = tester.element(find.byType(CatalogueDetailScreen));
    showInkSheet<void>(
      context: context,
      child: const SizedBox(height: 200, child: Text('Modal publication')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('navigation-settings')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/catalogue/series/series-a',
    );
    expect(find.text('Modal publication'), findsNothing);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'account controls live in Settings and old links redirect there',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('reader@example.test'), findsNothing);
      expect(find.text('Server'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      await tester.tap(find.text('Servers and account'));
      await tester.pumpAndSettle();
      expect(find.text('Server'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      final router = harness.container.read(routerProvider);
      router.go('/settings/account');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/servers',
      );
      expect(find.text('Account and connection'), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out of Inkora?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/servers',
      );
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  registerCatalogueRetentionTest();

  testWidgets(
    'theme selection is applied and persisted, global reading settings open',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(
        harness.container.read(uiPreferencesProvider).requireValue.appearance,
        AppAppearance.dark,
      );
      harness.container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reading'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Global defaults').first);
      await tester.pumpAndSettle();
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('This book'), findsNothing);
      expect(find.text('Preference inheritance'), findsNothing);
      expect(find.text('Inherit'), findsNothing);
      expect(find.text('Reset to default'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets('200 percent system text remains usable at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester, textScale: 2);
      final router = harness.container.read(routerProvider);
      for (final location in [
        '/',
        '/libraries',
        '/settings',
        '/settings/accessibility',
        '/catalogue/book/book-a',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }
      await harness.close(tester);
    });
  }

  test('theme foreground pairs meet normal text contrast', () {
    double contrast(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    for (final theme in [
      InkoraTheme.light(),
      InkoraTheme.dark(),
      InkoraTheme.dark(amoled: true),
      InkoraTheme.sepia(),
      InkoraTheme.ocean(),
      InkoraTheme.forest(),
    ]) {
      final scheme = theme.colorScheme;
      expect(
        contrast(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.surface, scheme.onSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(scheme.surface, scheme.onSurfaceVariant),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(
          theme.snackBarTheme.backgroundColor!,
          theme.snackBarTheme.contentTextStyle!.color!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(
          theme.snackBarTheme.backgroundColor!,
          theme.snackBarTheme.actionTextColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

/// Shared state-retention scenario for host and focused device verification.
void registerCatalogueRetentionTest() {
  testWidgets('library selection, search and filters survive tab changes', (
    tester,
  ) async {
    final harness = await UiHarness.create(tester);
    addTearDown(() => harness.close(tester));
    await harness.mount(tester);
    await tester.tap(find.text('Libraries'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manga shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Moonlit District'), findsOneWidget);
    expect(find.text('Atlas Nine'), findsNothing);
    await tester.tap(find.byKey(const Key('catalogue-search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalogue-search')),
      'Moonlit',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Libraries'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('catalogue-search')))
          .controller!
          .text,
      'Moonlit',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Manga shelf'), findsOneWidget);
    await tester.tap(find.byTooltip('Show list'));
    await tester.tap(find.byKey(const Key('catalogue-filters')));
    await tester.pumpAndSettle();
    expect(find.text('List view'), findsNothing);
    await tester.tap(find.text('Show unavailable items'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalogue-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
