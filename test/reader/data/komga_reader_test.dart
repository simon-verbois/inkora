import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/komga_reader_remote.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  late Map<String, dynamic> book;
  late List<dynamic> pages;
  late FixtureAdapter adapter;
  setUp(() {
    book =
        (jsonDecode(
                      File(
                        'test/fixtures/komga/1.28.1/catalogue/local-book-0.json',
                      ).readAsStringSync(),
                    )['content']
                    as List)
                .first
            as Map<String, dynamic>;
    pages = (jsonDecode(
      File('test/fixtures/komga/1.28.1/local-pages.json').readAsStringSync(),
    ) as List).take(1).toList();
    adapter = FixtureAdapter((options) {
      if (options.path.endsWith('/pages')) return jsonResponse(pages);
      if (options.path.contains('/pages/')) {
        return ResponseBody.fromBytes(
          fixtureRaster,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      }
      return jsonResponse(book);
    });
  });
  test('versioned manifest and binary requests preserve subpath, bounds and one-based numbering', () async {
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final manifest = await KomgaReaderRemote.loadManifest(
      client,
      savedSession.accountId,
      book['id'] as String,
      CancelToken(),
    );
    expect(manifest.pages.single.width, 32);
    expect(manifest.pages.single.height, 48);
    final remote = KomgaReaderRemote(client, manifest);
    final page = await remote.read(
      manifest.key(0),
      cancellation: CancellationController(),
    );
    expect(page.bytes, fixtureRaster);
    expect(
      adapter.requests.last.uri.path,
      '/komga/api/v1/books/${book['id']}/pages/1',
    );
    expect(adapter.requests.last.headers['Accept'], contains('image/'));
    expect(() => manifest.key(1), throwsRangeError);
    expect(
      () => client.pageImage('book', -1, cancelToken: CancelToken()),
      throwsArgumentError,
    );
  });
  test('revision changes with file content while metadata titles do not change content identity', () async {
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final first = await KomgaReaderRemote.loadManifest(
      client,
      'account',
      book['id'] as String,
      CancelToken(),
    );
    (book['metadata'] as Map)['title'] = 'Edited metadata';
    final same = await KomgaReaderRemote.loadManifest(
      client,
      'account',
      book['id'] as String,
      CancelToken(),
    );
    expect(first.revision, same.revision);
    book['fileHash'] = 'new-file-content-hash';
    final changed = await KomgaReaderRemote.loadManifest(
      client,
      'account',
      book['id'] as String,
      CancelToken(),
    );
    expect(first.revision, isNot(changed.revision));
  });
  test('unsupported format, missing revision and inconsistent page count fail safely', () async {
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    (book['media'] as Map)['mediaProfile'] = 'EPUB';
    await expectLater(
      KomgaReaderRemote.loadManifest(
        client,
        'account',
        book['id'] as String,
        CancelToken(),
      ),
      throwsA(
        isA<ReaderFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.notFound,
        ),
      ),
    );
    (book['media'] as Map)['mediaProfile'] = 'DIVINA';
    (book['media'] as Map)['pagesCount'] = 2;
    await expectLater(
      KomgaReaderRemote.loadManifest(
        client,
        'account',
        book['id'] as String,
        CancelToken(),
      ),
      throwsA(isA<ReaderFailure>()),
    );
    (book['media'] as Map)['pagesCount'] = 1;
    book.remove('fileHash');
    book.remove('fileLastModified');
    await expectLater(
      KomgaReaderRemote.loadManifest(
        client,
        'account',
        book['id'] as String,
        CancelToken(),
      ),
      throwsA(isA<ReaderFailure>()),
    );
  });
  test(
    'non-image content and oversized streams cannot enter the page cache',
    () async {
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      addTearDown(client.close);
      final manifest = await KomgaReaderRemote.loadManifest(
        client,
        'account',
        book['id'] as String,
        CancelToken(),
      );
      adapter = FixtureAdapter(
        (_) => ResponseBody.fromString(
          '<html>not an image</html>',
          200,
          headers: {
            'content-type': ['text/html'],
          },
        ),
      );
      final bad = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      addTearDown(bad.close);
      await expectLater(
        KomgaReaderRemote(
          bad,
          manifest,
        ).read(manifest.key(0), cancellation: CancellationController()),
        throwsA(
          isA<ReaderFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.corruptContent,
          ),
        ),
      );
      await expectLater(
        client.pageImage(
          'book',
          0,
          cancelToken: CancelToken(),
          maximumBytes: 10,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.corruptContent,
          ),
        ),
      );
    },
  );
  test('in-flight binary cancellation interrupts a held stream', () async {
    final chunks = StreamController<Uint8List>();
    adapter = FixtureAdapter(
      (_) => ResponseBody(
        chunks.stream,
        200,
        headers: {
          'content-type': ['image/png'],
        },
      ),
    );
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final signal = CancellationController();
    final page = KomgaReaderRemote(
      client,
      readerManifest(count: 1),
    ).read(readerManifest(count: 1).key(0), cancellation: signal);
    final check = expectLater(
      page,
      throwsA(
        isA<ReaderFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.cancelled,
        ),
      ),
    );
    chunks.add(Uint8List.fromList([137, 80]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    signal.cancel();
    await check;
    await chunks.close();
  });
  test('saved manifest and locator open offline without waiting for networking; refresh 401 stays denied', () async {
    final folder = await Directory.systemTemp.createTemp(
      'inkora-reader-repository-',
    );
    final database = AppDatabase(NativeDatabase.memory());
    final store = ReaderStore(database, 'reader-account');
    await store.saveManifest(readerManifest());
    await store.saveLocator(readerManifest(), ReaderLocator(2, .25));
    adapter = FixtureAdapter((_) => jsonResponse({}, status: 401));
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    final repository = ReaderRepository(
      store,
      ReaderAssetStore(
        database,
        Directory('${folder.path}/cache'),
        Directory('${folder.path}/download'),
      ),
      client,
      PageNetworkGate(),
      isCurrent: () => true,
    );
    try {
      final opened = await repository.open('reader-book');
      expect(opened.locator.pageIndex, 2);
      expect(opened.locator.fraction, .25);
      expect(adapter.requests, isEmpty);
      await expectLater(
        repository.open('reader-book', refresh: true),
        throwsA(
          isA<ReaderFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.authentication,
          ),
        ),
      );
    } finally {
      repository.close();
      client.close();
      await database.close();
      await folder.delete(recursive: true);
    }
  });
}
