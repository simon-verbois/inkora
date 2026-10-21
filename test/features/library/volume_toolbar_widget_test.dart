import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';

Future<void> mountToolbar(
  WidgetTester tester,
  VolumeBrowserController controller, {
  double width = 390,
  double scale = 1,
  String locale = 'en',
  bool reduced = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: InkoraTheme.forest(),
      locale: Locale(locale),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: VolumeToolbar(controller: controller),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 780.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('volume filters and actions share one row at $width/$scale', (
        tester,
      ) async {
        final controller = VolumeBrowserController();
        addTearDown(controller.dispose);
        await mountToolbar(
          tester,
          controller,
          width: width,
          scale: scale,
          locale: 'de',
        );
        final menu = find.byKey(const Key('volume-quick-filters'));
        final inline = find.byKey(const Key('volume-filter-all'));
        final filters = menu.evaluate().isNotEmpty ? menu : inline;
        expect(filters.hitTestable(), findsOneWidget);
        final y = tester.getCenter(filters).dy;
        for (final key in ['volume-view', 'volume-order', 'volume-select']) {
          final action = find.byKey(Key(key));
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getCenter(action).dy, closeTo(y, 1));
          expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
        }
        expect(tester.getRect(filters).left, greaterThanOrEqualTo(0));
        expect(
          tester.getRect(filters).right,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const Key('volume-view'))).left,
          ),
        );
        if (width <= 390) expect(menu, findsOneWidget);
        if (width >= 780) expect(find.byType(InkFilterChip), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'compact menu applies checked filters, reduced motion $reduced',
      (tester) async {
        final controller = VolumeBrowserController();
        addTearDown(controller.dispose);
        await mountToolbar(tester, controller, locale: 'fr', reduced: reduced);
        final menu = find.byKey(const Key('volume-quick-filters'));
        for (final filter in VolumeFilter.values) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          final checked = tester.widgetList<CheckedPopupMenuItem<VolumeFilter>>(
            find.byType(CheckedPopupMenuItem<VolumeFilter>),
          );
          expect(
            checked.where((item) => item.checked).single.value,
            controller.filter,
          );
          expect(checked.map((item) => item.value), VolumeFilter.values);
          await tester.tap(
            find.byKey(ValueKey('volume-filter-${filter.name}')),
          );
          await tester.pumpAndSettle();
          expect(controller.filter, filter);
          final badge = tester.widget<Badge>(
            find.descendant(of: menu, matching: find.byType(Badge)),
          );
          expect(badge.isLabelVisible, filter != VolumeFilter.all);
        }
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(790, 590));
        await tester.pumpAndSettle();
        expect(controller.filter, VolumeFilter.downloaded);
        for (final key in ['volume-view', 'volume-order', 'volume-select']) {
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }
        expect(controller.grid, true);
        expect(controller.descending, true);
        expect(controller.selecting, true);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('resize and text scale preserve filters and controller state', (
    tester,
  ) async {
    final controller = VolumeBrowserController()
      ..filter = VolumeFilter.inProgress
      ..toggleOrder()
      ..toggleView();
    addTearDown(controller.dispose);
    for (final width in [390.0, 780.0, 390.0]) {
      await mountToolbar(tester, controller, width: width, locale: 'fr');
      expect(controller.filter, VolumeFilter.inProgress);
      expect(controller.grid, true);
      expect(controller.descending, true);
      expect(
        find.byKey(const Key('volume-quick-filters')),
        width == 390 ? findsOneWidget : findsNothing,
      );
    }
    await mountToolbar(tester, controller, width: 780, scale: 2, locale: 'de');
    expect(controller.filter, VolumeFilter.inProgress);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter menu switches exactly where the inline row fits', (
    tester,
  ) async {
    final controller = VolumeBrowserController();
    addTearDown(controller.dispose);
    await mountToolbar(tester, controller, width: 780);
    final first = tester.getRect(find.byKey(const Key('volume-filter-all')));
    final last = tester.getRect(
      find.byKey(const Key('volume-filter-downloaded')),
    );
    final threshold =
        (last.right - first.left).ceilToDouble() +
        InkSpace.lg +
        InkSpace.sm +
        3 * InkoraLayout.touchTarget;
    for (final delta in [-1.0, 0.0, 1.0]) {
      await mountToolbar(tester, controller, width: threshold + delta);
      expect(
        find.byKey(const Key('volume-quick-filters')),
        delta < 0 ? findsOneWidget : findsNothing,
      );
      if (delta >= 0) {
        final scroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('volume-chips')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scroll.position.maxScrollExtent, 0);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
