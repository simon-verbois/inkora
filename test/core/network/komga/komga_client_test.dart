import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/komga/komga_models.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/domain/session.dart';

import '../../../support/connection_fakes.dart';

Object? fixture(String name) => jsonDecode(
  File('test/fixtures/komga/1.28.1/$name.json').readAsStringSync(),
);
Matcher failure(FailureKind kind) =>
    isA<ApiFailure>().having((f) => f.kind, 'kind', kind);

void main() {
  late FixtureAdapter adapter;
  late KomgaClient client;
  setUp(() {
    adapter = FixtureAdapter((_) => jsonResponse(userJson));
    client = fixtureClient(
      ServerEndpoint('https://example.test/komga'),
      Credentials.apiKey('fixture'),
      adapter,
    );
  });
  tearDown(() => client.close());

  test(
    'deployed fixtures preserve zero-based pagination and opaque IDs',
    () async {
      adapter = FixtureAdapter(
        (options) => jsonResponse(
          fixture('deployed-books-${options.queryParameters['page']}'),
        ),
      );
      client.close();
      client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final first = await client.books(page: 0, size: 2);
      final second = await client.books(page: 1, size: 2);
      expect(first.number, 0);
      expect(second.number, 1);
      expect(first.items, hasLength(2));
      expect(first.items.first.id, isA<String>());
      expect(first.totalElements, greaterThan(2));
      expect(
        first.items
            .map((b) => b.id)
            .toSet()
            .intersection(second.items.map((b) => b.id).toSet()),
        isEmpty,
      );
      expect(adapter.requests.first.uri.path, '/komga/api/v1/books');
      expect(
        adapter.requests.first.queryParameters,
        containsPair('sort', 'id,asc'),
      );
    },
  );

  test('local last-page and empty pagination are decoded', () {
    final last = CataloguePage<KomgaBook>.fromJson(
      fixture('local-books-1'),
      KomgaBook.fromJson,
    );
    expect(last.last, isTrue);
    expect(last.items, hasLength(1));
    final empty = CataloguePage<KomgaBook>.fromJson({
      'content': <Object?>[],
      'number': 0,
      'size': 20,
      'totalElements': 0,
      'totalPages': 0,
      'numberOfElements': 0,
      'last': true,
    }, KomgaBook.fromJson);
    expect(empty.items, isEmpty);
  });

  test(
    'one-based page metadata and image URI convert only at adapter boundary',
    () async {
      adapter = FixtureAdapter((_) => jsonResponse(fixture('local-pages')));
      client.close();
      client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final pages = await client.pages('opaque book/#');
      expect(pages.map((p) => p.index), [0, 1, 2]);
      expect(
        client.pageUri('opaque book/#', 0).toString(),
        'https://example.test/komga/api/v1/books/opaque%20book%2F%23/pages/1',
      );
      expect(() => client.pageUri('..', 0), throwsArgumentError);
      expect(() => client.pageUri('book', -1), throwsArgumentError);
    },
  );

  test('PATCH and DELETE match server-verified progress semantics', () async {
    final first = KomgaBook.fromJson(fixture('local-progress-first'));
    final last = KomgaBook.fromJson(fixture('local-progress-last'));
    final reset = KomgaBook.fromJson(fixture('local-progress-reset'));
    final complete = KomgaBook.fromJson(fixture('local-progress-complete'));
    expect(first.progress!.pageIndex, 0);
    expect(first.progress!.completed, isFalse);
    expect(last.progress!.pageIndex, 2);
    expect(last.progress!.completed, isTrue);
    expect(reset.progress, isNull);
    expect(complete.progress!.completed, isTrue);
    await client.updateProgress('book/1', pageIndex: 0);
    await client.updateProgress('book/1', completed: true);
    await client.resetProgress('book/1');
    expect(adapter.requests[0].method, 'PATCH');
    expect(adapter.requests[0].data, {'page': 1});
    expect(adapter.requests[1].data, {'completed': true});
    expect(adapter.requests[2].method, 'DELETE');
    expect(
      adapter.requests[2].uri.path,
      '/komga/api/v1/books/book%2F1/read-progress',
    );
    expect(
      () => client.updateProgress('book', completed: false),
      throwsArgumentError,
    );
  });

  test('deployed schema capabilities are gated by account permissions', () {
    final user = parseUser(fixture('deployed-user'));
    final schema = fixture('openapi');
    final capabilities = KomgaCapabilities.fromOpenApi(schema, user);
    expect(capabilities.version, '1.28.1');
    expect(capabilities.pageStreaming, isTrue);
    expect(capabilities.fileDownload, isTrue);
    expect(capabilities.progress, isTrue);
    expect(capabilities.divina, isTrue);
    expect(capabilities.epub, isTrue);
    expect(capabilities.pdf, isTrue);
    final restricted = KomgaCapabilities.fromOpenApi(
      schema,
      parseUser(fixture('local-restricted-user')),
    );
    expect(restricted.pageStreaming, isFalse);
    expect(restricted.fileDownload, isFalse);
    expect(restricted.epub, isFalse);
    expect(restricted.progress, isTrue);
  });

  for (final status in [403, 404, 500]) {
    test(
      'optional schema $status keeps capabilities conservative without logout',
      () async {
        adapter = FixtureAdapter((_) => jsonResponse({}, status: status));
        client.close();
        client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          adapter,
        );
        final capabilities = await client.negotiateCapabilities(
          savedSession.user,
        );
        expect(capabilities.schemaAvailable, isFalse);
        expect(capabilities.epub, isFalse);
      },
    );
  }

  for (final entry in {
    401: FailureKind.authentication,
    403: FailureKind.permission,
    404: FailureKind.notFound,
    429: FailureKind.rateLimited,
    503: FailureKind.transientNetwork,
    302: FailureKind.serverRejected,
  }.entries) {
    test(
      'status ${entry.key} maps safely without following redirects',
      () async {
        adapter = FixtureAdapter((options) {
          expect(options.followRedirects, isFalse);
          return jsonResponse(
            {'authorization': 'do-not-display'},
            status: entry.key,
            headers: {
              'location': ['https://other.test'],
              'retry-after': ['12'],
            },
          );
        });
        client.close();
        client = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          adapter,
        );
        var expired = false;
        client.onUnauthorized = () => expired = true;
        await expectLater(client.currentUser(), throwsA(failure(entry.value)));
        expect(expired, entry.key == 401);
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test(
    'unknown fields are tolerated; invalid user DTOs are rejected',
    () async {
      adapter = FixtureAdapter(
        (_) => jsonResponse({...userJson, 'futureField': true}),
      );
      client.close();
      client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      expect((await client.currentUser()).id, 'opaque-user');
      for (final malformed in [
        {'id': 12},
        '<html>proxy</html>',
        {
          'id': 'x',
          'email': 'x',
          'roles': [5],
        },
      ]) {
        final badAdapter = FixtureAdapter((_) => jsonResponse(malformed));
        final bad = fixtureClient(
          savedSession.endpoint,
          savedSession.credentials,
          badAdapter,
        );
        await expectLater(
          bad.currentUser(),
          throwsA(failure(FailureKind.corruptContent)),
        );
        bad.close();
      }
    },
  );

  test('inconsistent catalogue page and page numbering fail safely', () async {
    final wrong = jsonObject(fixture('local-books-0'))..['number'] = 3;
    adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.path.endsWith('/pages')
            ? [
                {'number': 0, 'mediaType': 'image/png'},
              ]
            : wrong,
      ),
    );
    client.close();
    client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    await expectLater(
      client.books(),
      throwsA(failure(FailureKind.corruptContent)),
    );
    await expectLater(
      client.pages('book'),
      throwsA(failure(FailureKind.corruptContent)),
    );
  });

  test(
    'caller cancellation and session close cancel pending requests',
    () async {
      final pending = Completer<ResponseBody>();
      adapter = FixtureAdapter((_) => pending.future);
      client.close();
      client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final token = CancelToken();
      final request = client.books(cancelToken: token);
      token.cancel();
      await expectLater(request, throwsA(failure(FailureKind.cancelled)));
      final second = client.currentUser();
      client.close();
      await expectLater(second, throwsA(failure(FailureKind.cancelled)));
      pending.complete(jsonResponse(userJson));
    },
  );

  test('retry delay and certificate failures remain sanitized', () {
    final request = RequestOptions(headers: {'Authorization': 'private'});
    final rate = ApiFailure.fromDio(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['9'],
          }),
        ),
      ),
    );
    expect(rate.retryAfter, const Duration(seconds: 9));
    final tls = ApiFailure.fromDio(
      DioException(
        requestOptions: request,
        type: DioExceptionType.badCertificate,
      ),
    );
    expect(tls.allowsOfflineRestore, isFalse);
    expect(tls.toString(), isNot(contains('private')));
  });
}
