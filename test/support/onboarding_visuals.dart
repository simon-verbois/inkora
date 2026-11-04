import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_settings.dart';
import 'package:inkora/reader/presentation/ebook_fonts.dart';

/// Real glyph metrics catch narrow labels that the default test font misses.
Future<void> loadOnboardingFonts() async {
  for (final (family, asset) in [
    ('LibreBaskerville', 'assets/fonts/LibreBaskerville.ttf'),
    ('PhosphorRegular', 'assets/icons/Phosphor-Regular.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    for (final font in EbookFont.values)
      if (font.previewFamily != null && font != EbookFont.baskerville)
        (font.previewFamily!, 'assets/fonts/${font.previewFamily}-Regular.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  final directory =
      '$sdk/bin/cache/dart-sdk/bin/resources/devtools/assets/'
      'packages/devtools_app_shared/fonts/Roboto';
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(
      File('$directory/Roboto-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView),
    );
  }
  await loader.load();
}

Future<void> captureOnboarding(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('CAPTURE_ONBOARDING')) return;
  await tester.runAsync(() async {
    final render = tester.renderObject<RenderRepaintBoundary>(boundary);
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('artifacts/onboarding/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

Future<void> chooseSetupMode(WidgetTester tester, String mode) async {
  final selector = find.byKey(const Key('reader-mode-selector'));
  await tester.ensureVisible(selector);
  await tester.pumpAndSettle();
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('reader-mode-option-$mode')).last;
  final target = find
      .ancestor(of: option, matching: find.byType(InkWell))
      .first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
