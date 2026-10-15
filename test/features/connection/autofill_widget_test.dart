import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/presentation/connection_screen.dart';

import '../../support/connection_fakes.dart';

void main() {
  testWidgets(
    'tagged email/password autofill survives visibility and rejects stale mode tags',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(Future.value(database)),
            sessionStoreProvider.overrideWithValue(MemorySessionStore()),
          ],
          child: const MaterialApp(home: ConnectionScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Username / email'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('username')));
      await tester.pump();
      EditableTextState field(String key) => tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      );
      final emailTag = field('username').autofillId;
      final passwordTag = field('secret').autofillId;
      Future<void> fill() async {
        final message = const JSONMethodCodec().encodeMethodCall(
          MethodCall('TextInputClient.updateEditingStateWithTag', [
            0,
            {
              emailTag: const TextEditingValue(text: 'reader@example.test')
                  .toJSON(),
              passwordTag: const TextEditingValue(text: 'fixture-password')
                  .toJSON(),
            },
          ]),
        );
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/textinput',
          message,
          (_) {},
        );
        await tester.pump();
      }

      await fill();
      expect(field('username').widget.controller.text, 'reader@example.test');
      expect(field('secret').widget.controller.text, 'fixture-password');
      await tester.tap(find.byTooltip('Show secret'));
      await tester.pump();
      expect(field('secret').autofillId, passwordTag);
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('secret')));
      await tester.pump();
      expect(field('secret').autofillId, isNot(passwordTag));
      expect(field('secret').widget.autofillHints, isNull);
      await fill();
      expect(field('secret').widget.controller.text, isEmpty);
      await tester.tap(find.text('Username / email'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('username')));
      await tester.pump();
      expect(field('username').autofillId, isNot(emailTag));
      await fill();
      expect(field('secret').widget.controller.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await fill();
      expect(tester.takeException(), isNull);
    },
  );
}
