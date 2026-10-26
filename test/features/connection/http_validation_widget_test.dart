import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/presentation/connection_screen.dart';

import '../../support/connection_fakes.dart';

void main() {
  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'HTTP validation and wrapped URL errors at 320dp/200%/$locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(Future.value(database)),
              sessionStoreProvider.overrideWithValue(MemorySessionStore()),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const ConnectionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('server-url')),
          'ftp://example.test',
        );
        await tester.enterText(
          find.byKey(const Key('secret')),
          'synthetic-key',
        );
        final form = tester.state<FormState>(find.byType(Form));
        expect(form.validate(), isFalse);
        await tester.pumpAndSettle();
        final message = AppStrings(locale.languageCode)
            .text('Enter an HTTP or HTTPS URL, including any server subpath.');
        expect(find.text(message), findsOneWidget);
        final error = tester.widget<Text>(find.text(message));
        expect(error.maxLines, 8);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const Key('server-url')),
          'http://192.168.1.20:25600/komga',
        );
        expect(form.validate(), isTrue);
        await tester.pumpAndSettle();
        expect(find.text(message), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
