import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/features/connection/domain/session.dart';

import '../../../support/connection_fakes.dart';

const _user = {
  'id': 'user-1',
  'email': 'reader@example.test',
  'roles': ['USER'],
};

void main() {
  final basic = Credentials.basic('reader@example.test', 'secret');
  final sent = <({String? authorization, String? token})>[];

  FixtureAdapter server({
    required Set<String> validTokens,
    bool passwordValid = true,
  }) {
    var issued = 0;
    return FixtureAdapter((options) {
      final authorization = options.headers['Authorization'] as String?;
      final token = options.headers['X-Auth-Token'] as String?;
      sent.add((authorization: authorization, token: token));
      if (token != null && token.isNotEmpty) {
        // Komga rejects an unknown/expired session even with Basic present.
        return validTokens.contains(token)
            ? jsonResponse(_user)
            : jsonResponse({}, status: 401);
      }
      if (authorization == null || !passwordValid) {
        return jsonResponse({}, status: 401);
      }
      final created = 'session-${++issued}';
      validTokens.add(created);
      return jsonResponse(
        _user,
        headers: {
          'x-auth-token': [created],
        },
      );
    });
  }

  setUp(sent.clear);

  test(
    'password accounts send the session token alone after the first response',
    () async {
      final adapter = server(validTokens: {});
      final client = KomgaClient(
        savedSession.endpoint,
        basic,
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      await client.currentUser();
      await client.currentUser();
      await client.currentUser();
      expect(sent.first.authorization, startsWith('Basic '));
      expect(sent.first.token, '');
      for (final request in sent.skip(1)) {
        expect(request.authorization, isNull);
        expect(request.token, 'session-1');
      }
    },
  );

  test(
    'an expired session is replayed once with the password and renewed',
    () async {
      final valid = <String>{};
      final adapter = server(validTokens: valid);
      final client = KomgaClient(
        savedSession.endpoint,
        basic,
        dio: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      var unauthorized = 0;
      client.onUnauthorized = () => unauthorized++;
      await client.currentUser();
      valid.clear(); // Server-side expiry or logout elsewhere.
      expect((await client.currentUser()).id, 'user-1');
      expect(unauthorized, 0);
      expect(sent[1].token, 'session-1');
      expect(sent[2].authorization, startsWith('Basic '));
      await client.currentUser();
      expect(sent.last.token, 'session-2');
      expect(sent.last.authorization, isNull);
    },
  );

  test('a rejected password remains an authentication failure', () async {
    final adapter = server(validTokens: {}, passwordValid: false);
    final client = KomgaClient(
      savedSession.endpoint,
      basic,
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.close);
    var unauthorized = 0;
    client.onUnauthorized = () => unauthorized++;
    await expectLater(
      client.currentUser(),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.authentication,
        ),
      ),
    );
    expect(unauthorized, 1);
    expect(sent, hasLength(1));
  });

  test('API-key accounts are unchanged', () async {
    final adapter = server(validTokens: {});
    final client = KomgaClient(
      savedSession.endpoint,
      Credentials.apiKey('key'),
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(client.close);
    await expectLater(client.currentUser(), throwsA(isA<ApiFailure>()));
    expect(sent.single.token, isNull);
  });
}
