import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/presentation/catalogue_link_button.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  final calls = <(String, LaunchOptions)>[];
  bool succeeds = true;
  bool throws = false;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url, options));
    if (throws) throw PlatformException(code: 'unavailable');
    return succeeds;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  String url = 'https://example.test/book?q=one',
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: InkoraTheme.forest(),
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: CatalogueLinkButton(link: CatalogueLink('Open Library', url)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _Launcher launcher;
  setUp(() {
    final previous = UrlLauncherPlatform.instance;
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
  });
  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'external link confirmation and cancellation at 200% in $locale',
      (tester) async {
        await _pump(tester, locale: locale);
        final strings = AppStrings(locale.languageCode);
        await tester.tap(find.text('Open Library'));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Open external link?')), findsOneWidget);
        expect(find.text('https://example.test/book?q=one'), findsOneWidget);
        expect(launcher.calls, isEmpty);
        await tester.tap(find.byKey(const Key('ink-confirm-cancel')));
        await tester.pumpAndSettle();
        expect(launcher.calls, isEmpty);
        await tester.tap(find.text('Open Library'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(launcher.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final width in [320.0, 480.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('metadata links wrap after three at $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final links = [
          for (var i = 0; i < 7; i++)
            CatalogueLink('Metadata website $i', 'https://example.test/$i'),
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: InkoraTheme.forest(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CatalogueLinks(links: links),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rects = [
          for (final link in links)
            tester.getRect(find.byKey(ValueKey('catalogue-link-${link.url}'))),
        ];
        expect(rects[0].top, rects[1].top);
        expect(rects[1].top, rects[2].top);
        expect(rects[3].top, greaterThanOrEqualTo(rects[0].bottom));
        expect(rects[3].top, rects[4].top);
        expect(rects[4].top, rects[5].top);
        expect(rects[6].top, greaterThanOrEqualTo(rects[3].bottom));
        expect(rects[0].left, rects[3].left);
        expect(rects[0].left, rects[6].left);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Metadata website 3'));
        await tester.pumpAndSettle();
        expect(find.text('https://example.test/3'), findsOneWidget);
        expect(launcher.calls, isEmpty);
      });
    }
  }
  testWidgets('only confirmation launches the exact URL externally', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Open Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ink-confirm-accept')));
    await tester.pumpAndSettle();
    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single.$1, 'https://example.test/book?q=one');
    expect(
      launcher.calls.single.$2.mode,
      PreferredLaunchMode.externalApplication,
    );
    expect(launcher.calls.single.$2.webViewConfiguration.headers, isEmpty);
  });
  for (final throws in [false, true]) {
    testWidgets('failed launch reports an error and allows retry ($throws)', (
      tester,
    ) async {
      launcher.succeeds = false;
      launcher.throws = throws;
      await _pump(tester);
      await tester.tap(find.text('Open Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ink-confirm-accept')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open this link.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Open Library'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('non-web metadata never opens another app', (tester) async {
    await _pump(tester, url: 'javascript:alert(1)');
    await tester.tap(find.text('Open Library'));
    await tester.pumpAndSettle();
    expect(launcher.calls, isEmpty);
    expect(find.text('Unable to open this link.'), findsOneWidget);
  });
}
