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

  Future<void> write(String accountId, String secret) =>
      _storage.write(key: _key(accountId), value: secret);

  Future<void> delete(String accountId) =>
      _storage.delete(key: _key(accountId));
}
