import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/release_information.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/features/settings/presentation/about_content.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  final calls = <(String, LaunchOptions)>[];
  bool succeeds = true, throws = false;
  Completer<bool>? pending;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url, options));
    if (throws) throw PlatformException(code: 'unavailable');
    return pending == null ? succeeds : await pending!.future;
  }
}

Future<void> mount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(320, 640),
  double scale = 2,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        releaseInformationProvider.overrideWith(
          (ref) async => const ReleaseInformation('2026.43.7', []),
        ),
      ],
      child: MaterialApp(
        theme: InkoraTheme.dark(),
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(16), child: AboutContent()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('about-support')));
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
      'one official support image is visible and accessible at 320dp/200%/$locale',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await mount(tester, locale: locale);
        final button = find.byKey(const Key('about-support'));
        expect(button, findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.bySemanticsLabel('Buy Me a Coffee'), findsOneWidget);
        expect(launcher.calls, isEmpty);
        final image = tester.widget<Image>(find.byType(Image));
        final resized = image.image as ResizeImage;
        expect(
          (resized.imageProvider as AssetImage).assetName,
          'assets/branding/buy-me-a-coffee.png',
        );
        expect(resized.width, 178);
        final rect = tester.getRect(button);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'tablet button opens the retained support destination in the external browser once',
    (tester) async {
      await mount(tester, size: const Size(1024, 768), scale: 1);
      await tester.tap(find.byKey(const Key('about-support')));
      await tester.pumpAndSettle();
      expect(launcher.calls, hasLength(1));
      expect(launcher.calls.single.$1, 'https://buymeacoffee.com/simonverbois');
      expect(
        launcher.calls.single.$2.mode,
        PreferredLaunchMode.externalApplication,
      );
      expect(launcher.calls.single.$2.webViewConfiguration.headers, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an outstanding browser launch disables duplicate support presses',
    (tester) async {
      launcher.pending = Completer<bool>();
      await mount(tester);
      final button = find.byKey(const Key('about-support'));
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.pump();
      expect(launcher.calls, hasLength(1));
      launcher.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'failed external support launch reports an error and allows retry ($throws)',
      (tester) async {
        launcher.succeeds = false;
        launcher.throws = throws;
        await mount(tester);
        final button = find.byKey(const Key('about-support'));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Unable to open this link.'), findsOneWidget);
        expect(tester.widget<TextButton>(button).onPressed, isNotNull);
        launcher.succeeds = true;
        launcher.throws = false;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(launcher.calls, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
