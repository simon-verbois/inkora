import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';

Future<BuildContext> mountNotification(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  String locale = 'en',
  double textScale = 1,
  bool accessible = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: InkoraTheme.light(),
      locale: AppStrings.localeFor(locale),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          accessibleNavigation: accessible,
        ),
        child: InkNotificationTheme(child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return captured;
}

Finder notificationSurface() => find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

void main() {
  testWidgets('rapid notifications keep only the latest without replay', (
    tester,
  ) async {
    final context = await mountNotification(tester);
    notifyInk(context, 'Reading status updated: {0}', arguments: ['1 volume']);
    await tester.pumpAndSettle();
    for (var i = 2; i <= 8; i++) {
      notifyInk(
        context,
        'Reading status updated: {0}',
        arguments: ['$i volumes'],
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('Reading status updated: 8 volumes'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('success expires quickly and action notifications can time out', (
    tester,
  ) async {
    final context = await mountNotification(tester);
    notifyInk(context, 'Queued');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    var retried = 0;
    notifyInk(
      context,
      'Unable to save reading progress.',
      actionLabel: 'Retry',
      onAction: () => retried++,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, 1);
    notifyInk(
      context,
      'Unable to save reading progress.',
      actionLabel: 'Retry',
      onAction: () => retried++,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final dx in [-600.0, 600.0]) {
    testWidgets('notification can be dismissed sideways by $dx', (
      tester,
    ) async {
      final context = await mountNotification(tester);
      for (var i = 0; i < 4; i++) {
        notifyInk(context, 'Queued');
      }
      await tester.pumpAndSettle();
      await tester.fling(notificationSurface(), Offset(dx, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(SnackBar), findsNothing);
    });
  }

  testWidgets('screen reader action stays available until explicitly closed', (
    tester,
  ) async {
    final context = await mountNotification(tester, accessible: true);
    notifyInk(
      context,
      'Unable to save reading progress.',
      actionLabel: 'Retry',
      onAction: () {},
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('visible notification adapts to resize and keyboard', (
    tester,
  ) async {
    final context = await mountNotification(tester);
    notifyInk(context, 'Unable to save reading progress.');
    await tester.pumpAndSettle();
    expect(tester.getSize(notificationSurface()).width, 480);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    final rect = tester.getRect(notificationSurface());
    expect(rect.width, 288);
    expect(rect.left, 16);
    expect(rect.bottom, lessThanOrEqualTo(440));
    expect(tester.takeException(), isNull);
  });

  for (final locale in languageNames.keys) {
    for (final (size, scale) in [
      (const Size(320, 700), 2.0),
      (const Size(1280, 800), 1.0),
    ]) {
      testWidgets('notification fits $locale at $size/$scale', (tester) async {
        final context = await mountNotification(
          tester,
          size: size,
          locale: locale,
          textScale: scale,
        );
        notifyInk(
          context,
          'Reading status updated: {0}',
          arguments: [AppStrings.of(context).quantity(1, 'volume')],
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(notificationSurface());
        expect(rect.width, lessThanOrEqualTo(480));
        expect(rect.left, greaterThanOrEqualTo(16));
        expect(rect.right, lessThanOrEqualTo(size.width - 16));
        expect(rect.center.dx, closeTo(size.width / 2, .01));
        expect(tester.takeException(), isNull);
        final label = MaterialLocalizations.of(context).closeButtonTooltip;
        final close = find.byTooltip(label);
        expect(close.hitTestable(), findsOneWidget);
        final closeTarget = find.ancestor(
          of: close,
          matching: find.byType(IconButton),
        );
        expect(
          tester.getSize(closeTarget).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        var retries = 0;
        notifyInk(
          context,
          'Unable to save reading progress.',
          actionLabel: 'Retry',
          onAction: () => retries++,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(context.tr('Retry')));
        await tester.pumpAndSettle();
        expect(retries, 1);
      });
    }
  }
}
