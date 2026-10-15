import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/http_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';

void main() {
  test('preserves proxy prefix and resolves API paths', () {
    final endpoint = ServerEndpoint('https://example.test/komga');
    expect(
      endpoint.resolveApiPath('api/v2/users/me').toString(),
      'https://example.test/komga/api/v2/users/me',
    );
    final client = createHttpClient(endpoint);
    addTearDown(client.close);
    expect(client.options.baseUrl, 'https://example.test/komga/');
    expect(client.options.connectTimeout, const Duration(seconds: 15));
  });

  test('rejects unsafe server URLs and prefix-discarding API paths', () {
    for (final value in [
      'http://example.test',
      'https://user:secret@example.test',
      'https://example.test?a=b',
      'https://example.test#x',
    ]) {
      expect(() => ServerEndpoint(value), throwsArgumentError);
    }
    final endpoint = ServerEndpoint('https://example.test/komga/');
    for (final path in [
      '/api/v1/books',
      '../api/v1/books',
      'https://other.test/api',
      '//other.test/api',
    ]) {
      expect(() => endpoint.resolveApiPath(path), throwsArgumentError);
    }
  });
}
