import 'dart:convert';

import '../../../core/network/komga/komga_models.dart';
import '../../../core/network/server_endpoint.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/credential_store.dart';
import '../domain/session.dart';

/// The active pointer is published only after metadata and secrets are durable.
/// No network validation is needed to restore a previously verified identity.
final class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._database, this._credentials);
  final Future<AppDatabase> _database;
  final CredentialStore _credentials;
  static const _active = 'session.active';
  static const _accounts = 'session.accounts';

  @override
  Future<SavedSession?> restore() async {
    final account = await _credentials.read(_active);
    if (account == null) return null;
    final saved = await _read(account);
    if (saved == null) await clear();
    return saved;
  }

  Future<SavedSession?> _read(String account) async {
    final encoded = await _credentials.read(account);
    if (encoded == null) return null;
    try {
      final json = jsonObject(jsonDecode(encoded));
      final endpoint = ServerEndpoint(requiredString(json, 'baseUrl'));
      final user = parseUser(json['user']);
      final credentials = switch (requiredString(json, 'method')) {
        'apiKey' => Credentials.apiKey(requiredString(json, 'secret')),
        'basic' => Credentials.basic(
          requiredString(json, 'username'),
          requiredString(json, 'secret'),
        ),
        _ => throw const FormatException('Unknown authentication method'),
      };
      final session = SavedSession(
        endpoint: endpoint,
        user: user,
        credentials: credentials,
      );
      if (session.accountId != account) {
        throw const FormatException('Mismatched account');
      }
      final database = await _database;
      final profile =
          await (database.select(database.serverProfiles)
                ..where((row) => row.id.equals(endpoint.uri.toString())))
              .getSingleOrNull();
      if (profile == null || profile.baseUrl != endpoint.uri.toString()) {
        throw const FormatException('Missing profile');
      }
      return session;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<Set<String>> _ids() async {
    final encoded = await _credentials.read(_accounts);
    Set<String>? ids;
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List &&
            decoded.every((id) => id is String && id.isNotEmpty)) {
          ids = decoded.cast<String>().toSet();
        }
      } on FormatException {
        // Recover from verified records below, without deleting any secret.
      }
    }
    if (ids == null) {
      ids = <String>{};
      for (final id in await _credentials.keys()) {
        if (id.isEmpty || id == _active || id == _accounts) continue;
        if (await _read(id) != null) ids.add(id);
      }
    }
    // Adopt the existing single-account installation without a database migration.
    final active = await _credentials.read(_active);
    if (active != null && active.isNotEmpty) ids.add(active);
    return ids;
  }

  Future<void> _index(Set<String> ids) => ids.isEmpty
      ? _credentials.delete(_accounts)
      : _credentials.write(_accounts, jsonEncode(ids.toList()));

  @override
  Future<List<SavedSession>> savedSessions() async {
    final sessions = <SavedSession>[];
    for (final id in await _ids()) {
      final saved = await _read(id);
      if (saved != null) sessions.add(saved);
    }
    return sessions;
  }

  @override
  Future<SavedSession?> activate(String accountId) async {
    if (!(await _ids()).contains(accountId)) return null;
    final saved = await _read(accountId);
    if (saved != null) await _credentials.write(_active, accountId);
    return saved;
  }

  @override
  Future<void> save(SavedSession session) async {
    final previous = await _credentials.read(session.accountId);
    final index = await _credentials.read(_accounts);
    await remember(session);
    try {
      await _credentials.write(_active, session.accountId);
    } catch (_) {
      await _restoreValue(session.accountId, previous);
      await _restoreValue(_accounts, index);
      rethrow;
    }
  }

  Future<void> _restoreValue(String key, String? value) =>
      value == null ? _credentials.delete(key) : _credentials.write(key, value);

  @override
  Future<void> remember(SavedSession session) async {
    final database = await _database;
    final url = session.endpoint.uri.toString();
    await database
        .into(database.serverProfiles)
        .insertOnConflictUpdate(
          ServerProfilesCompanion.insert(
            id: url,
            displayName: session.endpoint.uri.host,
            baseUrl: url,
          ),
        );
    final previous = await _credentials.read(session.accountId);
    await _credentials.write(
      session.accountId,
      jsonEncode({
        'baseUrl': url,
        'user': {
          'id': session.user.id,
          'email': session.user.email,
          'roles': session.user.roles.toList(),
        },
        'method': session.credentials.method.name,
        'username': session.credentials.username,
        'secret': session.credentials.secret,
      }),
    );
    try {
      await _index((await _ids())..add(session.accountId));
    } catch (_) {
      await _restoreValue(session.accountId, previous);
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    final account = await _credentials.read(_active);
    // Keep the pointer until secret deletion succeeds, so cleanup can be retried.
    if (account != null) {
      await forget(account);
    } else {
      await _credentials.delete(_active);
    }
  }

  @override
  Future<void> forget(String accountId) async {
    final ids = await _ids();
    await _credentials.delete(accountId);
    if (await _credentials.read(_active) == accountId) {
      await _credentials.delete(_active);
    }
    await _index(ids..remove(accountId));
  }
}
