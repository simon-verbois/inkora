import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';

import '../support/connection_fakes.dart';
import '../support/reader_fakes.dart';

void main() {
  test('stream-to-file enforces header/chunk budgets, complete length and one-based pages', () async {
    final root = await Directory.systemTemp.createTemp('inkora-stream-');
    addTearDown(() => root.delete(recursive: true));
    var claimed = fixtureRaster.length;
    final adapter = FixtureAdapter(
      (_) => ResponseBody.fromBytes(
        fixtureRaster,
        200,
        headers: {
          'content-type': ['image/png'],
          'content-length': ['$claimed'],
        },
      ),
    );
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final file = File('${root.path}/page.part');
    final result = await client.pageToFile(
      'book',
      0,
      file,
      cancelToken: CancelToken(),
      maximumBytes: fixtureRaster.length,
    );
    expect(result.byteLength, fixtureRaster.length);
    expect(await file.readAsBytes(), fixtureRaster);
    expect(adapter.requests.last.uri.path, '/komga/api/v1/books/book/pages/1');
    claimed = fixtureRaster.length + 1;
    await expectLater(
      client.pageToFile(
        'book',
        0,
        file,
        cancelToken: CancelToken(),
        maximumBytes: fixtureRaster.length,
      ),
      throwsA(isA<ApiFailure>()),
    );
    claimed = fixtureRaster.length - 1;
    await expectLater(
      client.pageToFile(
        'book',
        0,
        file,
        cancelToken: CancelToken(),
        maximumBytes: fixtureRaster.length,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('progress uses book read-back, verified revision and one-based PATCH/DELETE contracts', () async {
    final book =
        (jsonDecode(
                      File(
                        'test/fixtures/komga/1.28.1/catalogue/local-book-0.json',
                      ).readAsStringSync(),
                    )['content']
                    as List)
                .first
            as Map<String, dynamic>;
    final pages = (jsonDecode(
      File('test/fixtures/komga/1.28.1/local-pages.json').readAsStringSync(),
    ) as List).take(1).toList();
    book['readProgress'] = {
      'page': 1,
      'completed': false,
      'lastModified': '2026-10-11T12:00:00Z',
    };
    final adapter = FixtureAdapter((request) {
      if (request.path.endsWith('/pages')) return jsonResponse(pages);
      if (request.path.endsWith('/read-progress')) {
        if (request.method == 'DELETE') {
          book['readProgress'] = null;
        } else {
          book['readProgress'] = {
            ...request.data as Map<String, dynamic>,
            'lastModified': '2026-10-11T12:01:00Z',
          };
        }
        return ResponseBody.fromString('', 204);
      }
      return jsonResponse(book);
    });
    final KomgaClient client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final remote = KomgaProgressRemote(client, 'account');
    final first = await remote.read(book['id'] as String);
    expect(first.pageIndex, 0);
    expect(first.version, '2026-10-11T12:00:00Z');
    await remote.write(
      book['id'] as String,
      ProgressSnapshot(revision: first.revision, pageIndex: 0),
    );
    expect(adapter.requests.last.method, 'PATCH');
    expect((adapter.requests.last.data as Map)['page'], 1);
    final after = await remote.read(book['id'] as String);
    expect(after.version, '2026-10-11T12:01:00Z');
    await remote.write(
      book['id'] as String,
      ProgressSnapshot(revision: first.revision),
    );
    expect(adapter.requests.last.method, 'DELETE');
    expect((await remote.read(book['id'] as String)).pageIndex, isNull);
    expect(
      adapter.requests.where(
        (r) => r.method == 'GET' && r.path.endsWith('/read-progress'),
      ),
      isEmpty,
    );
  });
}
