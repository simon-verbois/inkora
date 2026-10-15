import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/core/storage/credential_store.dart';
import 'package:inkora/features/connection/domain/session.dart';

const userJson = {
  'id': 'opaque-user',
  'email': 'reader@example.test',
  'roles': ['USER', 'PAGE_STREAMING'],
};
final savedSession = SavedSession(
  endpoint: ServerEndpoint('https://example.test/komga/'),
  user: const KomgaUser(
    id: 'opaque-user',
    email: 'reader@example.test',
    roles: {'USER', 'PAGE_STREAMING'},
  ),
  credentials: Credentials.apiKey('test-fixture-key'),
);

ResponseBody jsonResponse(
  Object? json, {
  int status = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: {
    'content-type': ['application/json'],
    ...?headers,
  },
);

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

KomgaClient fixtureClient(
  ServerEndpoint endpoint,
  Credentials credentials,
  FixtureAdapter adapter,
) {
  return KomgaClient(
    endpoint,
    credentials,
    dio: Dio()..httpClientAdapter = adapter,
  );
}

class MemorySessionStore implements SessionStore {
  final accounts = <String, SavedSession>{};
  SavedSession? saved;
  Completer<SavedSession?>? restoration;
  Completer<void>? saving;
  bool failSave = false;
  bool failClear = false;
  int saves = 0;
  int clears = 0;
  @override
  Future<SavedSession?> restore() async =>
      restoration == null ? saved : restoration!.future;
  @override
  Future<void> save(SavedSession session) async {
    saves++;
    if (saving != null) await saving!.future;
    if (failSave) throw StateError('storage failure');
    saved = session;
    accounts[session.accountId] = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    if (failClear) throw StateError('storage failure');
    if (saved != null) accounts.remove(saved!.accountId);
    saved = null;
  }

  @override
  Future<List<SavedSession>> savedSessions() async {
    final current = saved;
    if (current != null) {
      accounts[current.accountId] = current;
    }
    return accounts.values.toList();
  }

  @override
  Future<void> remember(SavedSession session) async {
    if (failSave) throw StateError('storage failure');
    await savedSessions();
    accounts[session.accountId] = session;
  }

  @override
  Future<SavedSession?> activate(String accountId) async {
    if (failSave) throw StateError('storage failure');
    final session = accounts[accountId];
    if (session != null) saved = session;
    return session;
  }

  @override
  Future<void> forget(String accountId) async {
    if (saved?.accountId == accountId) {
      await clear();
    } else {
      accounts.remove(accountId);
    }
  }
}

class MemoryCredentials extends CredentialStore {
  final values = <String, String>{};
  String? failWriteKey;
  @override
  Future<String?> read(String accountId) async => values[accountId];
  @override
  Future<void> write(String accountId, String secret) async {
    if (accountId == failWriteKey) throw StateError('secure write failure');
    values[accountId] = secret;
  }

  @override
  Future<void> delete(String accountId) async {
    values.remove(accountId);
  }
}
