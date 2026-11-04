import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/theme/inkora_theme.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/features/connection/presentation/connection_screen.dart';

import '../../support/connection_fakes.dart';
import '../../support/onboarding_visuals.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final locale in AppStrings.supportedLocales) {
    for (final (size, scale) in [
      (const Size(320, 640), 1.0),
      (const Size(390, 844), 1.0),
      (const Size(320, 640), 2.0),
      (const Size(1024, 768), 1.0),
    ]) {
      testWidgets(
        'authentication labels fit in both modes at $size/$scale/$locale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          const capture = Key('login-capture');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(Future.value(database)),
                sessionStoreProvider.overrideWithValue(MemorySessionStore()),
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
                  child: RepaintBoundary(key: capture, child: child!),
                ),
                home: const ConnectionScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final selector = find.byType(SegmentedButton<AuthenticationMethod>);
          final strings = AppStrings(locale.languageCode);
          final label = find.descendant(
            of: selector,
            matching: find.text(strings.text('Username / email')),
          );
          for (final method in [
            AuthenticationMethod.apiKey,
            AuthenticationMethod.basic,
          ]) {
            if (method == AuthenticationMethod.basic) {
              await tester.ensureVisible(label);
              await tester.pumpAndSettle();
              await tester.tap(label);
              await tester.pumpAndSettle();
            }
            final paragraph = tester.renderObject<RenderParagraph>(label);
            expect(paragraph.didExceedMaxLines, isFalse);
            if (scale == 1 && size.width >= 390) {
              final lines = paragraph
                  .getBoxesForSelection(
                    TextSelection(
                      baseOffset: 0,
                      extentOffset: paragraph.text.toPlainText().length,
                    ),
                  )
                  .map((box) => box.top)
                  .toSet();
              expect(
                lines.length,
                1,
                reason: 'The authentication label must remain on one line.',
              );
            }
            expect(
              tester.getRect(selector).contains(tester.getRect(label).center),
              isTrue,
            );
            expect(tester.takeException(), isNull);
            if (locale.languageCode == 'fr' && size.width == 390) {
              await captureOnboarding(
                tester,
                find.byKey(capture),
                'login-${method.name}-fr',
              );
            }
          }
          // Rotation and the keyboard must retain entered values and allow submit.
          await tester.enterText(
            find.byKey(const Key('username')),
            'reader@example.test',
          );
          await tester.enterText(
            find.byKey(const Key('secret')),
            'synthetic-password',
          );
          tester.view.physicalSize = Size(size.height, size.width);
          await tester.pumpAndSettle();
          final username = tester.widget<TextFormField>(
            find.byKey(const Key('username')),
          );
          expect(username.controller!.text, 'reader@example.test');
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, strings.text('Sign in')),
          );
          await tester.pumpAndSettle();
          expect(
            find
                .widgetWithText(FilledButton, strings.text('Sign in'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
