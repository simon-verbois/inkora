import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/komga_reader_remote.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';

import '../../support/connection_fakes.dart';

void main() {
  test('verified EPUB positions/progression use negotiated media and memoize positions', () async {
    Map<String, dynamic> fixture(String name) => jsonDecode(
      File('test/fixtures/komga/1.28.1/ebooks/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final book = fixture('epub-book');
    final positions = fixture('positions');
    var progression = fixture('progression');
    var lists = 0;
    Map<String, dynamic>? sent;
    final adapter = FixtureAdapter((options) {
      if (options.path.endsWith('/positions')) {
        expect(
          options.headers['Accept'],
          'application/vnd.readium.position-list+json',
        );
        lists++;
        return jsonResponse(positions);
      }
      if (options.path.endsWith('/progression')) {
        if (options.method == 'PUT') {
          sent = Map<String, dynamic>.from(options.data as Map);
          return ResponseBody.fromString('', 204);
        }
        expect(
          options.headers['Accept'],
          'application/vnd.readium.progression+json',
        );
        return jsonResponse(progression);
      }
      return jsonResponse(book);
    });
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final remote = KomgaProgressRemote(client, 'account');
    final initial = await remote.read('fixture-epub');
    expect(initial.documentLocator, isNotNull);
    await remote.read('fixture-epub');
    expect(lists, 1);
    await remote.write(
      'fixture-epub',
      ProgressSnapshot(
        revision: initial.revision,
        pageIndex: initial.pageIndex,
        documentLocator: initial.documentLocator,
        version: '2099-01-01T00:00:00Z',
      ),
    );
    expect(
      DateTime.parse(sent!['modified'] as String).isAfter(DateTime.utc(2099)),
      isTrue,
    );
    expect(
      sent!['locator'],
      EbookLocator.decode(initial.documentLocator!).value,
    );
    remote.trimMemory();
    await remote.read('fixture-epub');
    expect(lists, 2);
    progression = {
      'locator': {'href': '', 'type': ''},
      'modified': '2026-01-01T00:00:00Z',
    };
    expect((await remote.read('fixture-epub')).pageIndex, isNull);
  });
  test('PDF metadata opens without raster page endpoint', () async {
    final book = jsonDecode(
      File('test/fixtures/komga/1.28.1/ebooks/pdf-book.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final adapter = FixtureAdapter((options) {
      expect(options.path, endsWith('/fixture-pdf'));
      return jsonResponse(book);
    });
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      adapter,
    );
    addTearDown(client.close);
    final manifest = await KomgaReaderRemote.loadManifest(
      client,
      'account',
      'fixture-pdf',
      CancelToken(),
    );
    expect(manifest.isDocument, isTrue);
    expect(manifest.assetCount, 1);
    expect(manifest.pages.length, 3);
    expect(adapter.requests.length, 1);
  });
}
