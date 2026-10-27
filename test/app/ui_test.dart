import '../support/home_navigation.dart';
import 'home_navigation_widget_test.dart' show backEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
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
          expect(
            find.byKey(const Key('catalogue-pinned-tools')),
            findsOneWidget,
          );
          expect(find.byTooltip('Refresh catalogue'), findsNothing);
          expect(find.byTooltip('Search catalogue'), findsNothing);
          expect(find.byIcon(Icons.shield_outlined), findsNothing);
          final router = harness.container.read(routerProvider);
          for (final location in [
            '/',
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
                findsNothing,
                reason: location,
              );
            }
            expect(tester.takeException(), isNull, reason: location);
          }
          router.go('/');
          await tester.pumpAndSettle();
          expect(find.byTooltip('Search catalogue'), findsNothing);
          expect(find.text('Favorites'), findsNothing);
          if (size.width < 360) {
            expect(find.byKey(const Key('home-menu')), findsOneWidget);
          } else {
            expect(find.byKey(const Key('open-downloads')), findsOneWidget);
            expect(find.byKey(const Key('open-settings')), findsOneWidget);
          }
          expect(find.byKey(const Key('navigation-home')), findsNothing);
          expect(find.byKey(const Key('navigation-rail')), findsNothing);
          expect(
            find.byKey(const Key('floating-navigation-panel')),
            findsNothing,
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
            (widget) => widget is InkCoverTile && widget.item.id == 'series-a',
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
      expect(find.byTooltip('Search catalogue'), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets('publication sheet blocks detail Back behind its modal barrier', (
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
    // The shared sheet must cover the detail Back action.
    final context = tester.element(find.byType(CatalogueDetailScreen));
    expect(Navigator.of(context).canPop(), isTrue);
    showInkSheet<void>(
      context: context,
      child: const SizedBox(height: 200, child: Text('Modal publication')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('floating-header-back')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/catalogue/series/series-a',
    );
    expect(find.text('Modal publication'), findsOneWidget);
    // The covered series navigator is poppable. Back must target only the root
    // sheet, including cancellation, rather than popping that inactive stack.
    final accepted = await backEvent(tester, 'startBackGesture');
    await backEvent(tester, 'updateBackGestureProgress');
    await backEvent(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('Modal publication'), findsOneWidget);
    if (accepted == true) {
      expect(await backEvent(tester, 'startBackGesture'), isTrue);
      await backEvent(tester, 'updateBackGestureProgress');
      await backEvent(tester, 'commitBackGesture');
    } else {
      await tester.binding.handlePopRoute();
    }
    await tester.pumpAndSettle();
    expect(find.text('Modal publication'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/catalogue/series/series-a',
    );
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });

  testWidgets(
    'account controls live in Settings and old links redirect there',
    (tester) async {
      final harness = await UiHarness.create(tester);
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      await openHomeDestination(tester, 'settings');
      await tester.pumpAndSettle();
      expect(find.text('reader@example.test'), findsNothing);
      expect(find.text('Server'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
      await tester.tap(find.text('Servers and account'));
      await tester.pumpAndSettle();
      expect(find.text('Active account'), findsNothing);
      expect(find.byTooltip('Edit connection'), findsOneWidget);
      final router = harness.container.read(routerProvider);
      router.go('/settings/account');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/settings/servers',
      );
      expect(find.text('Account and connection'), findsNothing);
      await tester.tap(find.byTooltip('Remove server example.test'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this server?'), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.text('Appearance'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follow-system-theme')));
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
      harness.container.read(routerProvider).go('/settings/reading');
      await tester.pumpAndSettle();
      expect(find.text('Reading profiles'), findsOneWidget);
      await tester.tap(find.text('Manga shelf'));
      await tester.pumpAndSettle();
      // The page title names the scope; the editor repeats no title.
      expect(find.text('Manga shelf'), findsOneWidget);
      expect(find.text('Reading preferences'), findsNothing);
      expect(find.text('This book'), findsNothing);
      expect(find.text('Preference inheritance'), findsNothing);
      expect(find.text('Inherit'), findsNothing);
      expect(find.byKey(const Key('reader-settings-menu')), findsOneWidget);
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
        '/',
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

    for (final appearance in AppAppearance.values.skip(1)) {
      final theme = InkoraTheme.forAppearance(appearance);
      final scheme = theme.colorScheme;
      for (final surface in [
        theme.scaffoldBackgroundColor,
        scheme.surface,
        scheme.surfaceContainerHighest,
      ]) {
        expect(
          contrast(surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${appearance.name}: body text',
        );
        expect(
          contrast(surface, scheme.onSurfaceVariant),
          greaterThanOrEqualTo(4.5),
          reason: '${appearance.name}: secondary text',
        );
        expect(
          contrast(surface, theme.extension<InkoraColors>()!.heading),
          greaterThanOrEqualTo(4.5),
          reason: '${appearance.name}: heading',
        );
      }
      final button = theme.filledButtonTheme.style!;
      expect(
        contrast(
          button.backgroundColor!.resolve({})!,
          button.foregroundColor!.resolve({})!,
        ),
        greaterThanOrEqualTo(4.5),
        reason: '${appearance.name}: action button',
      );
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
    await openHomeDestination(tester, 'libraries');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manga shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Moonlit District'), findsOneWidget);
    expect(find.text('Atlas Nine'), findsNothing);
    if (find
        .byKey(const Key('open-search'))
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-search')).hitTestable().last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const Key('catalogue-search')),
      'Moonlit',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // A secondary route must retain the query even when expanded search
    // covers the header actions.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    harness.container.read(routerProvider).push<void>('/downloads');
    await tester.pumpAndSettle();
    await openHomeDestination(tester, 'libraries');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('catalogue-search')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'Moonlit',
    );
    await tester.pump(const Duration(milliseconds: 200));
    // The selector shows the name on wide windows, its tooltip everywhere.
    expect(find.byTooltip('Manga shelf'), findsOneWidget);
    await tester.tap(find.byTooltip('Show list'));
    await tester.tap(find.byKey(const Key('catalogue-filters')));
    await tester.pumpAndSettle();
    expect(find.text('List view'), findsNothing);
    await tester.tap(find.text('Show unavailable items'));
    await tester.tap(find.byKey(const Key('filters-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalogue-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await harness.close(tester);
  });
}
