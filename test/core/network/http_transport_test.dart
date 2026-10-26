import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/http_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';

void main() {
  test('explicit HTTP reaches a real server and never replays authenticated redirects', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    final authorization = <String?>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      authorization.add(request.headers.value('X-API-Key'));
      if (request.uri.path.endsWith('redirect')) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/leaked');
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"ok":true}');
      }
      await request.response.close();
    });
    final endpoint = ServerEndpoint('http://127.0.0.1:${server.port}/komga');
    final client = createHttpClient(endpoint);
    addTearDown(() => client.close(force: true));
    client.options.headers['X-API-Key'] = 'synthetic-http-key';
    expect((await client.get<Map<String, dynamic>>('api/v2/users/me')).data, {
      'ok': true,
    });
    client.options.validateStatus = (status) => status == HttpStatus.found;
    final redirect = await client.get<void>('redirect');
    expect(redirect.statusCode, HttpStatus.found);
    expect(paths, ['/komga/api/v2/users/me', '/komga/redirect']);
    expect(authorization, everyElement('synthetic-http-key'));
  });
}
