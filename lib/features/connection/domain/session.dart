import 'dart:convert';

import '../../../core/network/server_endpoint.dart';

enum AuthenticationMethod { apiKey, basic }

/// Optional startup request injected by the local development entry point.
final class StartupLogin {
  const StartupLogin(this.serverUrl, this.credentials);
  final String serverUrl;
  final Credentials credentials;
}

/// Secrets are deliberately absent from toString and metadata DTOs.
final class Credentials {
  Credentials.apiKey(String key)
    : method = AuthenticationMethod.apiKey,
      username = null,
      secret = key {
    if (key.trim().isEmpty || key.contains(RegExp(r'[\r\n]'))) {
      throw ArgumentError('Enter an API key');
    }
  }

  Credentials.basic(String login, String password)
    : method = AuthenticationMethod.basic,
      username = login.trim(),
      secret = password {
    if (username!.isEmpty || username!.contains(':') || password.isEmpty) {
      throw ArgumentError('Enter a username/email and password');
    }
  }

  final AuthenticationMethod method;
  final String? username;
  final String secret;

  Map<String, String> get headers => switch (method) {
    AuthenticationMethod.apiKey => {'X-API-Key': secret},
    AuthenticationMethod.basic => {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$username:$secret'))}',
    },
  };
}

final class KomgaUser {
  const KomgaUser({required this.id, required this.email, required this.roles});
  final String id;
  final String email;
  final Set<String> roles;
}

final class SavedSession {
  const SavedSession({
    required this.endpoint,
    required this.user,
    required this.credentials,
  });

  final ServerEndpoint endpoint;
  final KomgaUser user;
  final Credentials credentials;

  /// JSON tuple prevents collisions across URLs and opaque remote user IDs.
  String get accountId => jsonEncode([endpoint.uri.toString(), user.id]);
}

abstract interface class SessionStore {
  Future<SavedSession?> restore();
  Future<void> save(SavedSession session);
  Future<void> clear();
  Future<List<SavedSession>> savedSessions();
  Future<void> remember(SavedSession session);
  Future<SavedSession?> activate(String accountId);
  Future<void> forget(String accountId);
}

final class ActiveConnectionAlreadySaved implements Exception {
  const ActiveConnectionAlreadySaved();
}
