import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/core/network/server_endpoint.dart';

import '../../support/connection_fakes.dart';

void main() {
  late MemorySessionStore store;
  late FixtureAdapter adapter;
  late ProviderContainer container;
  SessionController controller() => container.read(sessionProvider.notifier);
  Future<void> flush() {
    container.read(sessionProvider);
    return Future<void>.delayed(const Duration(milliseconds: 20));
  }

  setUp(() {
    store = MemorySessionStore();
    adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.path.endsWith('users/me') ? userJson : {},
        status: options.path.endsWith('users/me') ? 200 : 404,
      ),
    );
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) =>
              fixtureClient(endpoint, credentials, adapter),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('adding and switching servers preserve saved connections and isolate active identity', () async {
    store.saved = savedSession;
    await flush();
    final original = controller().client;
    await controller().addServer(
      'https://second.test/komga',
      Credentials.apiKey('second-fixture'),
    );
    expect(
      container.read(sessionProvider).session!.accountId,
      savedSession.accountId,
    );
    expect(controller().client, same(original));
    final second = (await store.savedSessions()).firstWhere(
      (session) => session.endpoint.uri.host == 'second.test',
    );
    await controller().selectServer(second.accountId);
    await flush();
    expect(
      container.read(sessionProvider).session!.accountId,
      second.accountId,
    );
    expect(controller().client, isNot(same(original)));
    expect((await store.restore())!.accountId, second.accountId);
    await controller().logout();
    expect(
      (await store.savedSessions()).single.accountId,
      savedSession.accountId,
    );
    await controller().selectServer(savedSession.accountId);
    expect(container.read(sessionProvider).phase, SessionPhase.ready);
    expect(
      container.read(sessionProvider).session!.accountId,
      savedSession.accountId,
    );
  });

  test('failed switch keeps current client and identity usable', () async {
    store.saved = savedSession;
    await flush();
    final original = controller().client;
    final second = SavedSession(
      endpoint: ServerEndpoint('https://second.test'),
      user: savedSession.user,
      credentials: savedSession.credentials,
    );
    await store.remember(second);
    store.failSave = true;
    await expectLater(
      controller().selectServer(second.accountId),
      throwsStateError,
    );
    expect(container.read(sessionProvider).phase, SessionPhase.ready);
    expect(
      container.read(sessionProvider).session!.accountId,
      savedSession.accountId,
    );
    expect(controller().client, same(original));
  });

  test('adding the active connection cannot replace credentials under live repositories', () async {
    store.saved = savedSession;
    await flush();
    final original = controller().client;
    await expectLater(
      controller().addServer(
        savedSession.endpoint.uri.toString(),
        Credentials.apiKey('replacement-fixture'),
      ),
      throwsA(isA<ActiveConnectionAlreadySaved>()),
    );
    expect(controller().client, same(original));
    expect(
      (await store.restore())!.credentials.secret,
      savedSession.credentials.secret,
    );
    expect(await store.savedSessions(), hasLength(1));
  });

  test(
    'startup stays loading until storage resolves, then opens login',
    () async {
      store.restoration = Completer();
      expect(container.read(sessionProvider).phase, SessionPhase.restoring);
      await flush();
      expect(container.read(sessionProvider).phase, SessionPhase.restoring);
      store.restoration!.complete(null);
      await flush();
      expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
      expect(adapter.requests, isEmpty);
    },
  );

  for (final credentials in [
    Credentials.apiKey('fixture-key'),
    Credentials.basic('fixture@example.test', 'fixture-password'),
  ]) {
    test(
      '${credentials.method.name} verifies identity and saves before opening home',
      () async {
        await flush();
        store.saving = Completer();
        final login = controller().login(
          'https://example.test/komga',
          credentials,
        );
        await flush();
        expect(
          container.read(sessionProvider).phase,
          SessionPhase.authenticating,
        );
        store.saving!.complete();
        await login;
        expect(container.read(sessionProvider).phase, SessionPhase.ready);
        expect(store.saved!.accountId, savedSession.accountId);
        expect(adapter.requests.first.uri.path, '/komga/api/v2/users/me');
        expect(
          adapter.requests.first.headers,
          containsPair(
            credentials.headers.keys.single,
            credentials.headers.values.single,
          ),
        );
      },
    );
  }

  test('failed login is sanitized and never persists a session', () async {
    adapter = FixtureAdapter(
      (_) => jsonResponse({'password': 'leak-me'}, status: 401),
    );
    await flush();
    await controller().login(
      'https://example.test',
      Credentials.apiKey('secret-value'),
    );
    expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
    expect(store.saves, 0);
    expect(container.read(sessionProvider).message, isNot(contains('leak-me')));
    expect(
      container.read(sessionProvider).message,
      isNot(contains('secret-value')),
    );
  });

  test('secure write failure keeps login closed', () async {
    store.failSave = true;
    await flush();
    await controller().login(
      'https://example.test',
      Credentials.apiKey('fixture'),
    );
    expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
    expect(controller().client, isNull);
  });

  test('development startup login verifies and securely saves once', () async {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        startupLoginProvider.overrideWithValue(
          StartupLogin(
            'https://example.test/komga',
            Credentials.apiKey('fixture'),
          ),
        ),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) =>
              fixtureClient(endpoint, credentials, adapter),
        ),
      ],
    );
    await flush();
    expect(container.read(sessionProvider).phase, SessionPhase.ready);
    expect(store.saves, 1);
    await controller().logout();
    await flush();
    expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
    expect(store.saves, 1);
  });

  test(
    'restored session takes precedence over development startup login',
    () async {
      store.saved = savedSession;
      container.dispose();
      container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          startupLoginProvider.overrideWithValue(
            StartupLogin(
              'https://other.test',
              Credentials.apiKey('other-fixture'),
            ),
          ),
          komgaClientFactoryProvider.overrideWithValue(
            (endpoint, credentials) =>
                fixtureClient(endpoint, credentials, adapter),
          ),
        ],
      );
      await flush();
      expect(
        container.read(sessionProvider).session!.accountId,
        savedSession.accountId,
      );
      expect(store.saves, 0);
      expect(adapter.requests.first.uri.host, 'example.test');
    },
  );

  test('failed startup authentication leaves normal login available', () async {
    adapter = FixtureAdapter((_) => jsonResponse({}, status: 401));
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        startupLoginProvider.overrideWithValue(
          StartupLogin('https://example.test', Credentials.apiKey('fixture')),
        ),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) =>
              fixtureClient(endpoint, credentials, adapter),
        ),
      ],
    );
    await flush();
    expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
    expect(store.saves, 0);
  });

  test(
    'offline restoration retains verified identity without waiting for network',
    () async {
      store.saved = savedSession;
      final response = Completer<ResponseBody>();
      adapter = FixtureAdapter((_) => response.future);
      await flush();
      expect(container.read(sessionProvider).phase, SessionPhase.ready);
      expect(
        container.read(sessionProvider).session!.user.id,
        savedSession.user.id,
      );
      response.completeError(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      await flush();
      expect(container.read(sessionProvider).phase, SessionPhase.ready);
      expect(container.read(sessionProvider).offline, isTrue);
      expect(store.clears, 0);
    },
  );

  test('restored 401 expires credentials; 403 retains account', () async {
    store.saved = savedSession;
    adapter = FixtureAdapter((_) => jsonResponse({}, status: 401));
    await flush();
    expect(container.read(sessionProvider).phase, SessionPhase.expired);
    expect(store.saved, isNull);
    expect(controller().client, isNull);
  });

  test(
    'permission denial on restoration is not authentication expiry',
    () async {
      store.saved = savedSession;
      adapter = FixtureAdapter((_) => jsonResponse({}, status: 403));
      await flush();
      expect(container.read(sessionProvider).phase, SessionPhase.ready);
      expect(container.read(sessionProvider).message, 'Access denied.');
      expect(store.clears, 0);
    },
  );

  test('401 on any authenticated API request expires the session', () async {
    adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.path.endsWith('users/me') ? userJson : {},
        status: options.path.endsWith('users/me')
            ? 200
            : options.path.endsWith('books')
            ? 401
            : 404,
      ),
    );
    await flush();
    await controller().login(
      'https://example.test',
      Credentials.apiKey('fixture'),
    );
    final active = controller().client!;
    await expectLater(active.books(), throwsA(isA<Exception>()));
    await flush();
    expect(container.read(sessionProvider).phase, SessionPhase.expired);
    expect(store.saved, isNull);
  });

  test(
    'logout during pending login cancels requests and prevents late login',
    () async {
      await flush();
      final response = Completer<ResponseBody>();
      adapter = FixtureAdapter((_) => response.future);
      final login = controller().login(
        'https://example.test',
        Credentials.apiKey('fixture'),
      );
      await flush();
      await controller().logout();
      response.complete(jsonResponse(userJson));
      await login;
      expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
      expect(store.saved, isNull);
      expect(adapter.closed, isTrue);
    },
  );

  test('logout serializes after a pending secure save', () async {
    await flush();
    store.saving = Completer();
    final login = controller().login(
      'https://example.test',
      Credentials.apiKey('fixture'),
    );
    await flush();
    final logout = controller().logout();
    store.saving!.complete();
    await Future.wait([login, logout]);
    expect(store.saved, isNull);
    expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
  });

  test(
    'storage cleanup failure offers retry and does not reopen home',
    () async {
      store.failClear = true;
      await flush();
      await controller().logout();
      expect(container.read(sessionProvider).phase, SessionPhase.expired);
      store.failClear = false;
      await controller().logout();
      expect(container.read(sessionProvider).phase, SessionPhase.disconnected);
    },
  );
}
