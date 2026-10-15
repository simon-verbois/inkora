import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  test(
    'visible subscriber shares prefetch and survives its cancellation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-shared-cover-',
      );
      final response = Completer<ResponseBody>();
      final adapter = FixtureAdapter((_) => response.future);
      final client = fixtureClient(
        ServerEndpoint('https://example.test'),
        savedSession.credentials,
        adapter,
      );
      final repository = CoverRepository(
        client,
        PageNetworkGate(),
        directory,
        'account',
      );
      addTearDown(() async {
        repository.close();
        client.close();
        await repository.flush();
        await directory.delete(recursive: true);
      });
      const key = (kind: 'book', id: 'shared', modified: 0);
      final ahead = CancellationController();
      final warm = repository.load(key, ahead, speculative: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final visible = repository.load(key, CancellationController());
      ahead.cancel();
      expect(await warm, isNull);
      response.complete(
        ResponseBody.fromBytes(
          fixtureRaster,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        ),
      );
      final bytes = await visible;
      expect(bytes, fixtureRaster);
      expect(repository.peek(key), same(bytes));
      expect(adapter.requests, hasLength(1));
    },
  );
  test(
    'synchronous cover lookup preserves identity and obeys memory eviction',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-cover-memory-',
      );
      final adapter = FixtureAdapter(
        (_) => ResponseBody.fromBytes(
          fixtureRaster,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        ),
      );
      final client = fixtureClient(
        ServerEndpoint('https://example.test'),
        savedSession.credentials,
        adapter,
      );
      final repository = CoverRepository(
        client,
        PageNetworkGate(),
        directory,
        'account',
        memoryBudget: fixtureRaster.length,
      );
      addTearDown(() async {
        await repository.flush();
        repository.close();
        client.close();
        await directory.delete(recursive: true);
      });
      const first = (kind: 'book', id: 'first', modified: 1);
      const second = (kind: 'book', id: 'second', modified: 1);
      final firstBytes = await repository.load(first, CancellationController());
      expect(repository.peek(first), same(firstBytes));
      final secondBytes = await repository.load(
        second,
        CancellationController(),
      );
      expect(repository.peek(first), isNull);
      expect(repository.peek(second), same(secondBytes));
      expect(
        repository.peek((kind: 'book', id: 'second', modified: 2)),
        isNull,
      );
      await repository.flush();
      repository.close();
      expect(repository.peek(second), isNull);
    },
  );

  test('poster bytes persist offline, are account/revision scoped and bounded on disk', () async {
    final directory = await Directory.systemTemp.createTemp('inkora-covers-');
    addTearDown(() => directory.delete(recursive: true));
    final adapter = FixtureAdapter(
      (options) => ResponseBody.fromBytes(
        fixtureRaster,
        200,
        headers: {
          'content-type': ['image/png'],
          'content-length': ['${fixtureRaster.length}'],
        },
      ),
    );
    final client = fixtureClient(
      ServerEndpoint('https://example.test/komga/'),
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final gate = PageNetworkGate();
    final repository = CoverRepository(
      client,
      gate,
      directory,
      'account',
      diskBudget: fixtureRaster.length,
    );
    const key = (kind: 'book', id: 'opaque/id', modified: 1);
    expect(await repository.load(key, CancellationController()), fixtureRaster);
    expect(
      adapter.requests.single.uri.path,
      '/komga/api/v1/books/opaque%2Fid/thumbnail',
    );
    expect(adapter.requests.single.headers['X-API-Key'], 'test-fixture-key');
    await repository.flush();
    repository.close();
    final offline = FixtureAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final offlineClient = fixtureClient(
      ServerEndpoint('https://example.test/komga/'),
      savedSession.credentials,
      offline,
    );
    addTearDown(offlineClient.close);
    final reopened = CoverRepository(offlineClient, gate, directory, 'account');
    addTearDown(reopened.close);
    expect(await reopened.load(key, CancellationController()), fixtureRaster);
    expect(offline.requests, isEmpty);
    expect(
      await reopened.load((
        kind: 'book',
        id: 'opaque/id',
        modified: 2,
      ), CancellationController()),
      isNull,
    );
    final other = CoverRepository(offlineClient, gate, directory, 'other');
    addTearDown(other.close);
    expect(await other.load(key, CancellationController()), isNull);
    final bounded = CoverRepository(
      client,
      gate,
      directory,
      'account',
      diskBudget: fixtureRaster.length,
    );
    addTearDown(bounded.close);
    await bounded.load((
      kind: 'series',
      id: 'second',
      modified: 1,
    ), CancellationController());
    await bounded.flush();
    final files = await directory
        .list()
        .where((file) => file is File)
        .cast<File>()
        .toList();
    expect(files, hasLength(1));
    expect(await files.single.length(), fixtureRaster.length);
    expect(gate.active, 0);
  });

  test(
    'foreground demand cancels a cover and gets the shared gate immediately',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'inkora-cover-priority-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final stream = StreamController<Uint8List>();
      final started = Completer<void>();
      final adapter = FixtureAdapter((_) {
        started.complete();
        return ResponseBody(
          stream.stream,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      });
      final client = fixtureClient(
        ServerEndpoint('https://example.test'),
        savedSession.credentials,
        adapter,
      );
      addTearDown(client.close);
      final gate = PageNetworkGate(limit: 1);
      final repository = CoverRepository(client, gate, directory, 'account');
      addTearDown(repository.close);
      final cover = repository.load((
        kind: 'book',
        id: 'book',
        modified: 0,
      ), CancellationController());
      await started.future;
      final foreground = CancellationController();
      final request = PageRequest();
      final admission = gate.acquire(foreground, request);
      await admission.timeout(const Duration(seconds: 2));
      expect(await cover, isNull);
      await stream.close();
      expect(gate.active, 1);
      gate.release(request);
      expect(gate.active, 0);
    },
  );

  test('thumbnail transport rejects wrong media, oversized streams and bad identities', () async {
    for (final response in [
      ResponseBody.fromString(
        '<html/>',
        200,
        headers: {
          'content-type': ['text/html'],
        },
      ),
      ResponseBody.fromBytes(
        List.filled(5, 1),
        200,
        headers: {
          'content-type': ['image/png'],
        },
      ),
      ResponseBody.fromBytes(
        [1],
        200,
        headers: {
          'content-type': ['image/png'],
          'content-length': ['6'],
        },
      ),
    ]) {
      final client = fixtureClient(
        ServerEndpoint('https://example.test'),
        savedSession.credentials,
        FixtureAdapter((_) => response),
      );
      await expectLater(
        client.thumbnail(
          'book',
          'book',
          cancelToken: CancelToken(),
          maximumBytes: 4,
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        () => client.thumbnail('book', '..', cancelToken: CancelToken()),
        throwsArgumentError,
      );
      client.close();
    }
  });
}
