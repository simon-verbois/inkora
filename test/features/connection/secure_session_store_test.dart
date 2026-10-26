import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/data/secure_session_store.dart';
import 'package:inkora/features/connection/domain/session.dart';

import '../../support/connection_fakes.dart';

void main() {
  late AppDatabase database;
  late MemoryCredentials credentials;
  late SecureSessionStore store;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    credentials = MemoryCredentials();
    store = SecureSessionStore(Future.value(database), credentials);
  });
  tearDown(() => database.close());

  SavedSession second() => SavedSession(
    endpoint: ServerEndpoint('https://second.test/library'),
    user: savedSession.user,
    credentials: Credentials.apiKey('second-fixture'),
  );

  test(
    'multiple secure connections restore, switch and remove independently',
    () async {
      await store.save(savedSession);
      await store.remember(second());
      expect((await store.restore())!.accountId, savedSession.accountId);
      expect(await store.savedSessions(), hasLength(2));
      final reopened = SecureSessionStore(Future.value(database), credentials);
      expect(
        (await reopened.activate(second().accountId))!.accountId,
        second().accountId,
      );
      expect((await reopened.restore())!.credentials.secret, 'second-fixture');
      await reopened.clear();
      expect(await reopened.restore(), isNull);
      expect(
        (await reopened.savedSessions()).single.accountId,
        savedSession.accountId,
      );
      expect(
        (await reopened.activate(savedSession.accountId))!.accountId,
        savedSession.accountId,
      );
      await reopened.forget(second().accountId);
      expect((await reopened.restore())!.accountId, savedSession.accountId);
      await reopened.clear();
      expect(credentials.values, isEmpty);
    },
  );

  test('legacy active connection is adopted and invalid inactive records cannot activate', () async {
    await store.save(savedSession);
    credentials.values.remove('session.accounts');
    expect(
      (await store.savedSessions()).single.accountId,
      savedSession.accountId,
    );
    await store.remember(second());
    credentials.values[second().accountId] = '{}';
    expect(await store.activate(second().accountId), isNull);
    expect((await store.restore())!.accountId, savedSession.accountId);
    expect(await store.savedSessions(), hasLength(1));
  });

  test(
    'failed index and pointer writes preserve the previous connection',
    () async {
      await store.save(savedSession);
      credentials.failWriteKey = 'session.accounts';
      await expectLater(store.remember(second()), throwsStateError);
      expect(credentials.values[second().accountId], isNull);
      expect((await store.restore())!.accountId, savedSession.accountId);
      credentials.failWriteKey = 'session.active';
      await expectLater(store.save(second()), throwsStateError);
      expect(credentials.values[second().accountId], isNull);
      expect((await store.restore())!.accountId, savedSession.accountId);
      expect(await store.savedSessions(), hasLength(1));
    },
  );

  for (final corrupt in ['{', '{}', 'null', '42', '[null]', '[""]']) {
    test(
      'invalid account index $corrupt recovers every verified connection',
      () async {
        await store.save(savedSession);
        await store.remember(second());
        final previousSecret = credentials.values[savedSession.accountId];
        credentials.values['session.accounts'] = corrupt;
        credentials.values['broken-record'] = '{}';
        expect(
          (await store.savedSessions()).map((session) => session.accountId),
          unorderedEquals([savedSession.accountId, second().accountId]),
        );
        expect(credentials.values[savedSession.accountId], previousSecret);
        expect(
          (await store.activate(second().accountId))!.accountId,
          second().accountId,
        );
        await store.forget(savedSession.accountId);
        expect(
          (await store.savedSessions()).single.accountId,
          second().accountId,
        );
        expect(jsonDecode(credentials.values['session.accounts']!), [
          second().accountId,
        ]);
        await store.clear();
        expect(await store.restore(), isNull);
      },
    );
  }

  test(
    'a missing index recovers inactive accounts even without an active pointer',
    () async {
      await store.save(savedSession);
      await store.remember(second());
      credentials.values.remove('session.accounts');
      credentials.values.remove('session.active');
      expect(await store.restore(), isNull);
      expect(await store.savedSessions(), hasLength(2));
      await store.save(second());
      expect(await store.savedSessions(), hasLength(2));
      expect((await store.restore())!.accountId, second().accountId);
    },
  );

  test('HTTP and HTTPS connections keep separate identities and restore their scheme', () async {
    final http = SavedSession(
      endpoint: ServerEndpoint('http://example.test/komga/'),
      user: savedSession.user,
      credentials: savedSession.credentials,
    );
    await store.save(savedSession);
    await store.remember(http);
    expect(http.accountId, isNot(savedSession.accountId));
    expect((await store.activate(http.accountId))!.endpoint.uri.scheme, 'http');
    expect((await store.restore())!.endpoint.uri.scheme, 'http');
    expect(await store.savedSessions(), hasLength(2));
  });

  test('verified profile and credentials round-trip independently; logout preserves metadata', () async {
    expect(await store.restore(), isNull);
    await store.save(savedSession);
    final restored = (await store.restore())!;
    expect(restored.accountId, savedSession.accountId);
    expect(restored.credentials.secret, savedSession.credentials.secret);
    final profile = await database.select(database.serverProfiles).getSingle();
    expect(profile.baseUrl, 'https://example.test/komga/');
    expect(
      profile.toJson().values,
      isNot(contains(savedSession.credentials.secret)),
    );
    await store.clear();
    expect(await store.restore(), isNull);
    expect(credentials.values, isEmpty);
    expect(await database.select(database.serverProfiles).get(), hasLength(1));
  });

  test(
    'basic credentials preserve password and restored user identity',
    () async {
      await store.save(
        SavedSession(
          endpoint: savedSession.endpoint,
          user: savedSession.user,
          credentials: Credentials.basic(
            'test@example.test',
            '  fixture-password  ',
          ),
        ),
      );
      expect(
        (await store.restore())!.credentials.secret,
        '  fixture-password  ',
      );
    },
  );

  test('corrupt/mismatched secure records cannot open a session', () async {
    await store.save(savedSession);
    final json = jsonDecode(
      credentials.values[savedSession.accountId]!,
    ) as Map<String, dynamic>;
    (json['user'] as Map<String, dynamic>)['id'] = 'other-account';
    credentials.values[savedSession.accountId] = jsonEncode(json);
    expect(await store.restore(), isNull);
    expect(credentials.values, isEmpty);
  });

  test(
    'metadata alone and failed secure publication do not authenticate',
    () async {
      credentials.failWriteKey = 'session.active';
      await expectLater(store.save(savedSession), throwsStateError);
      expect(await store.restore(), isNull);
      expect(
        await database.select(database.serverProfiles).get(),
        hasLength(1),
      );
    },
  );
}
