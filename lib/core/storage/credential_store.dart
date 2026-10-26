import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-scoped secrets; never use the ordinary application database.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String accountId) {
    if (accountId.isEmpty) throw ArgumentError.value(accountId, 'accountId');
    return 'inkora.credentials.${Uri.encodeComponent(accountId)}';
  }

  Future<String?> read(String accountId) => _storage.read(key: _key(accountId));

  /// Enumerate only this app's logical keys when a session index needs recovery.
  /// Only key names leave this adapter; ordinary indexed reads never scan it.
  Future<Set<String>> keys() async {
    const prefix = 'inkora.credentials.';
    final keys = <String>{};
    for (final key in (await _storage.readAll()).keys) {
      if (!key.startsWith(prefix)) continue;
      try {
        keys.add(Uri.decodeComponent(key.substring(prefix.length)));
      } on ArgumentError {
        // A foreign or malformed key cannot identify a saved account.
      }
    }
    return keys;
  }

  Future<void> write(String accountId, String secret) =>
      _storage.write(key: _key(accountId), value: secret);

  Future<void> delete(String accountId) =>
      _storage.delete(key: _key(accountId));
}
