import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('recovery enumerates only owned, decodable logical secure-storage keys', () async {
    FlutterSecureStorage.setMockInitialValues({
      'inkora.credentials.%5B%22http%3A%2F%2Fexample.test%2F%22%2C%22user%22%5D':
          'synthetic-secret',
      'inkora.credentials.session.active': 'synthetic-pointer',
      'inkora.credentials.%ZZ': 'unusable-key',
      'other-app.secret': 'unrelated-secret',
    });
    expect(await CredentialStore().keys(), {
      '["http://example.test/","user"]',
      'session.active',
    });
  });
}
