import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:drift/native.dart';
import 'package:inkora/core/storage/app_database.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/domain/session.dart';

import 'support/connection_fakes.dart';

void main() {
  late AppDatabase database;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await UiPreferencesStore(database)
        .save(const UiPreferences(setupCompleted: true));
  });
  tearDown(() => database.close());
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    for (final method in AuthenticationMethod.values) {
      testWidgets('${method.name} login and guarded logout at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemorySessionStore();
        final adapter = FixtureAdapter(
          (options) => jsonResponse(
            options.path.endsWith('users/me') ? userJson : {},
            status: options.path.endsWith('users/me') ? 200 : 404,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(Future.value(database)),
            sessionStoreProvider.overrideWithValue(store),
            komgaClientFactoryProvider.overrideWithValue(
              (endpoint, credentials) =>
                  fixtureClient(endpoint, credentials, adapter),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const InkoraApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Connect your Komga server to start reading.'),
          findsOneWidget,
        );
        expect(find.text('Inkora'), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(
          tester.getCenter(find.text('Inkora')).dx,
          closeTo(size.width / 2, 1),
        );
        container.read(routerProvider).go('/');
        await tester.pumpAndSettle();
        expect(
          find.text('Connect your Komga server to start reading.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('server-url')),
          'https://example.test/komga',
        );
        if (method == AuthenticationMethod.basic) {
          await tester.tap(find.text('Username / email'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('username')),
            'reader@example.test',
          );
        }
        await tester.enterText(
          find.byKey(const Key('secret')),
          'fixture-secret',
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byKey(const Key('secret')),
                  matching: find.byType(EditableText),
                ),
              )
              .obscureText,
          isTrue,
        );
        await tester.ensureVisible(find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('library-selector')), findsOneWidget);
        expect(
          container.read(sessionProvider).session?.user.email,
          'reader@example.test',
        );
        container.read(routerProvider).go('/connections');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('library-selector')), findsOneWidget);
        container.read(routerProvider).go('/settings/account');
        await tester.pumpAndSettle();
        expect(find.text('reader@example.test'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sign out').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Connect your Komga server to start reading.'),
          findsOneWidget,
        );
        expect(store.saved, isNull);
        container.read(routerProvider).go('/');
        await tester.pumpAndSettle();
        expect(
          find.text('Connect your Komga server to start reading.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(database.close);
      });
    }
  }

  testWidgets('startup loading resolves to restored authenticated home', (
    tester,
  ) async {
    final restore = Completer<SavedSession?>();
    final store = MemorySessionStore()..restoration = restore;
    final adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.path.endsWith('users/me') ? userJson : {},
        status: options.path.endsWith('users/me') ? 200 : 404,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(Future.value(database)),
          sessionStoreProvider.overrideWithValue(store),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) =>
                fixtureClient(endpoint, credentials, adapter),
          ),
        ],
        child: const InkoraApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text('Connect your Komga server to start reading.'),
      findsNothing,
    );
    restore.complete(savedSession);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selector')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(database.close);
  });

  testWidgets('invalid URL and rejected login show useful errors', (
    tester,
  ) async {
    final adapter = FixtureAdapter((_) => jsonResponse({}, status: 401));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(Future.value(database)),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) =>
                fixtureClient(endpoint, credentials, adapter),
          ),
        ],
        child: const InkoraApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('server-url')),
      'http://example.test',
    );
    await tester.enterText(find.byKey(const Key('secret')), 'fixture-key');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter an HTTPS URL, including any server subpath.'),
      findsOneWidget,
    );
    expect(adapter.requests, isEmpty);
    await tester.enterText(
      find.byKey(const Key('server-url')),
      'https://example.test',
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.text('Authentication failed. Please sign in again.'),
      findsOneWidget,
    );
    expect(find.text('Your next great read'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
