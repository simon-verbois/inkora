import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_kind.dart';
import '../../../core/network/komga/api_failure.dart';
import '../../../core/network/komga/komga_client.dart';
import '../../../core/network/komga/komga_models.dart';
import '../../../core/network/server_endpoint.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/credential_store.dart';
import '../data/secure_session_store.dart';
import '../domain/session.dart';

enum SessionPhase { restoring, disconnected, authenticating, ready, expired }

final class SessionState {
  const SessionState(
    this.phase, {
    this.session,
    this.message,
    this.offline = false,
    this.capabilities = const KomgaCapabilities(),
    this.connectionsRevision = 0,
  });
  final SessionPhase phase;
  final SavedSession? session;
  final String? message;
  final bool offline;
  final KomgaCapabilities capabilities;
  final int connectionsRevision;
}

final databaseProvider = Provider<Future<AppDatabase>>((ref) {
  final database = openAppDatabase();
  ref.onDispose(() => unawaited(database.then((db) => db.close())));
  return database;
});
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(
    ref.watch(databaseProvider),
    ref.watch(credentialStoreProvider),
  ),
);
typedef KomgaClientFactory = KomgaClient Function(
  ServerEndpoint endpoint,
  Credentials credentials,
);
final komgaClientFactoryProvider = Provider<KomgaClientFactory>(
  (ref) => KomgaClient.new,
);
final startupLoginProvider = Provider<StartupLogin?>((ref) => null);
final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Network repositories rebind after verified credential edits, including when
/// the account identity stays the same. Saved inactive-server edits do not emit.
final activeConnectionTransportProvider = Provider<KomgaClient?>((ref) {
  final identity = ref.watch(
    sessionProvider.select(
      (s) => (s.phase, s.session?.accountId, s.session?.credentials),
    ),
  );
  return identity.$1 == SessionPhase.ready
      ? ref.read(sessionProvider.notifier).client
      : null;
});

final savedSessionsProvider = FutureProvider<List<SavedSession>>((ref) {
  ref.watch(
    sessionProvider.select(
      (state) =>
          (state.phase, state.session?.accountId, state.connectionsRevision),
    ),
  );
  return ref.watch(sessionStoreProvider).savedSessions();
}, retry: (_, _) => null);

final class SessionController extends Notifier<SessionState> {
  late SessionStore _store;
  late KomgaClientFactory _factory;
  KomgaClient? _client;
  var _generation = 0;
  var _connectionsRevision = 0;
  var _disposed = false;
  Future<void> _storageTail = Future.value();

  KomgaClient? get client => state.phase == SessionPhase.ready ? _client : null;

  @override
  SessionState build() {
    _store = ref.read(sessionStoreProvider);
    _factory = ref.read(komgaClientFactoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _client?.close();
    });
    unawaited(Future.microtask(_restore));
    return const SessionState(SessionPhase.restoring);
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _connectionsChanged() {
    final previous = state;
    state = SessionState(
      previous.phase,
      session: previous.session,
      message: previous.message,
      offline: previous.offline,
      capabilities: previous.capabilities,
      connectionsRevision: ++_connectionsRevision,
    );
  }

  Future<T> _persist<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _restore() async {
    if (_disposed) return;
    final generation = _generation;
    try {
      final saved = await _persist(_store.restore);
      if (!_current(generation)) return;
      if (saved == null) {
        state = const SessionState(SessionPhase.disconnected);
        final startup = ref.read(startupLoginProvider);
        if (startup != null) {
          await login(startup.serverUrl, startup.credentials);
        }
        return;
      }
      final client = _factory(saved.endpoint, saved.credentials);
      _client = client;
      client.onUnauthorized = () => unawaited(_expire(generation));
      state = SessionState(SessionPhase.ready, session: saved);
      // Route immediately to local content; verification never gates offline entry.
      unawaited(_verify(saved, client, generation));
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
          SessionPhase.disconnected,
          message: 'Unable to restore secure storage. Try signing in again.',
        );
      }
    }
  }

  /// Optional OpenAPI discovery downloads the whole server schema. It never
  /// gates entering the app; the result is merged into the current state.
  Future<void> _negotiate(
    KomgaClient client,
    KomgaUser user,
    int generation,
  ) async {
    try {
      final capabilities = await client.negotiateCapabilities(user);
      final current = state;
      if (!_current(generation) || current.phase != SessionPhase.ready) return;
      state = SessionState(
        current.phase,
        session: current.session,
        message: current.message,
        offline: current.offline,
        capabilities: capabilities,
        connectionsRevision: current.connectionsRevision,
      );
    } catch (_) {
      /* Optional; 401 handling stays with the client's unauthorized hook. */
    }
  }

  Future<void> _verify(
    SavedSession saved,
    KomgaClient client,
    int generation,
  ) async {
    try {
      final user = await client.currentUser();
      if (!_current(generation)) return;
      if (user.id != saved.user.id) {
        await _expire(generation);
        return;
      }
      state = SessionState(
        SessionPhase.ready,
        session: SavedSession(
          endpoint: saved.endpoint,
          user: user,
          credentials: saved.credentials,
        ),
        capabilities: state.capabilities,
      );
      unawaited(_negotiate(client, user, generation));
    } on ApiFailure catch (error) {
      if (!_current(generation)) return;
      if (error.kind == FailureKind.authentication) {
        await _expire(generation);
      } else {
        state = SessionState(
          SessionPhase.ready,
          session: saved,
          offline: error.allowsOfflineRestore,
          message: error.message,
        );
      }
    }
  }

  Future<void> login(String serverUrl, Credentials credentials) async {
    if (state.phase == SessionPhase.authenticating ||
        state.phase == SessionPhase.restoring ||
        state.phase == SessionPhase.ready) {
      return;
    }
    final generation = ++_generation;
    KomgaClient? candidate;
    state = const SessionState(SessionPhase.authenticating);
    try {
      final endpoint = ServerEndpoint(serverUrl.trim());
      candidate = _factory(endpoint, credentials);
      _client = candidate;
      final user = await candidate.currentUser();
      if (!_current(generation)) {
        candidate.close();
        return;
      }
      final saved = SavedSession(
        endpoint: endpoint,
        user: user,
        credentials: credentials,
      );
      await _persist(() => _store.save(saved));
      if (!_current(generation)) {
        candidate.close();
        return;
      }
      candidate.onUnauthorized = () => unawaited(_expire(generation));
      state = SessionState(SessionPhase.ready, session: saved);
      unawaited(_negotiate(candidate, user, generation));
    } catch (error) {
      candidate?.close();
      if (!_current(generation)) return;
      _client = null;
      state = SessionState(
        SessionPhase.disconnected,
        message: switch (error) {
          ApiFailure failure => failure.message,
          ArgumentError _ => 'Enter a valid HTTPS server URL.',
          _ => 'Unable to save the session securely. Please try again.',
        },
      );
    }
  }

  Future<void> _expire(int generation) async {
    if (!_current(generation)) return;
    ++_generation;
    _client?.close();
    _client = null;
    state = const SessionState(
      SessionPhase.expired,
      message: 'Your session has expired. Please sign in again.',
    );
    try {
      await _persist(_store.clear);
    } catch (_) {
      if (!_disposed && state.phase == SessionPhase.expired) {
        state = const SessionState(
          SessionPhase.expired,
          message: 'Session expired. Secure storage cleanup failed; retry signing out.',
        );
      }
    }
  }

  /// Validate a new connection without disrupting the active account/client.
  Future<void> addServer(String url, Credentials credentials) async {
    final generation = _generation;
    final endpoint = ServerEndpoint(url.trim());
    final candidate = _factory(endpoint, credentials);
    try {
      final user = await candidate.currentUser();
      final saved = SavedSession(
        endpoint: endpoint,
        user: user,
        credentials: credentials,
      );
      if (state.session?.accountId == saved.accountId) {
        throw const ActiveConnectionAlreadySaved();
      }
      await _persist(() async {
        if (!_current(generation)) throw StateError('Session changed');
        await _store.remember(saved);
      });
      if (_current(generation)) {
        _connectionsChanged();
      }
    } finally {
      candidate.close();
    }
  }

  /// Verify replacement credentials before changing the saved or active connection.
  Future<void> updateServer(
    SavedSession previous,
    String url,
    Credentials credentials,
  ) async {
    final generation = _generation;
    final endpoint = ServerEndpoint(url.trim());
    final candidate = _factory(endpoint, credentials);
    var adopted = false;
    try {
      final user = await candidate.currentUser();
      final updated = SavedSession(
        endpoint: endpoint,
        user: user,
        credentials: credentials,
      );
      final active = state.session?.accountId == previous.accountId;
      await _persist(() async {
        if (!_current(generation)) throw StateError('Session changed');
        final saved = await _store.savedSessions();
        if (!saved.any((s) => s.accountId == previous.accountId)) {
          throw StateError('Saved connection unavailable');
        }
        if (updated.accountId != previous.accountId &&
            saved.any((s) => s.accountId == updated.accountId)) {
          throw const ActiveConnectionAlreadySaved();
        }
        if (active) {
          await _store.save(updated);
        } else {
          await _store.remember(updated);
        }
        if (updated.accountId != previous.accountId) {
          try {
            await _store.forget(previous.accountId);
          } catch (_) {
            if (active) {
              await _store.save(previous);
            } else {
              await _store.remember(previous);
            }
            await _store.forget(updated.accountId);
            rethrow;
          }
        }
      });
      if (!_current(generation)) return;
      if (active) {
        final next = ++_generation;
        _client?.close();
        _client = candidate;
        adopted = true;
        candidate.onUnauthorized = () => unawaited(_expire(next));
        state = SessionState(SessionPhase.ready, session: updated);
        unawaited(_negotiate(candidate, user, next));
      }
      _connectionsChanged();
    } finally {
      if (!adopted) candidate.close();
    }
  }

  Future<void> selectServer(String accountId) async {
    if (accountId == state.session?.accountId) return;
    final generation = _generation;
    final saved = await _persist(() async {
      if (!_current(generation)) return null;
      return _store.activate(accountId);
    });
    if (!_current(generation)) return;
    if (saved == null) throw StateError('Saved connection unavailable');
    final next = ++_generation;
    _client?.close();
    final client = _factory(saved.endpoint, saved.credentials);
    _client = client;
    client.onUnauthorized = () => unawaited(_expire(next));
    state = SessionState(SessionPhase.ready, session: saved);
    _connectionsChanged();
    unawaited(_verify(saved, client, next));
  }

  Future<void> removeServer(String accountId) async {
    if (accountId == state.session?.accountId) {
      await logout();
    } else {
      await _persist(() => _store.forget(accountId));
    }
    if (!_disposed) _connectionsChanged();
  }

  Future<void> logout() async {
    final generation = ++_generation;
    _client?.close();
    _client = null;
    state = const SessionState(SessionPhase.restoring);
    try {
      await _persist(_store.clear);
      if (_current(generation)) {
        state = const SessionState(SessionPhase.disconnected);
      }
    } catch (_) {
      if (_current(generation)) {
        state = const SessionState(
          SessionPhase.expired,
          message: 'Secure storage cleanup failed. Retry signing out.',
        );
      }
    }
  }
}
