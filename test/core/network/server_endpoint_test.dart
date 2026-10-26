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
      'ftp://example.test',
      'file:///tmp/server',
      '//example.test',
      'http://user:secret@example.test',
      'http://example.test?a=b',
      'http://example.test#x',
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

  for (final address in [
    'http://example.test/komga',
    'http://192.168.1.20:25600/komga',
    'http://[::1]:25600/komga',
  ]) {
    test('accepts explicit HTTP and retains its proxy path: $address', () {
      final endpoint = ServerEndpoint(address);
      expect(endpoint.uri.scheme, 'http');
      expect(
        endpoint.resolveApiPath('api/v2/users/me').toString(),
        '$address/api/v2/users/me',
      );
      final client = createHttpClient(endpoint);
      addTearDown(client.close);
      expect(client.options.baseUrl, '$address/');
      expect(client.options.followRedirects, isFalse);
    });
  }
}
