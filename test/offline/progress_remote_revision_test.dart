import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/offline/data/progress_sync.dart';

import '../support/connection_fakes.dart';

void main() {
  test(
    'progress reads reuse the memoized revision until the book file changes',
    () async {
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
      final adapter = FixtureAdapter(
        (request) => request.path.endsWith('/pages')
            ? jsonResponse(pages)
            : jsonResponse(book),
      );
      final KomgaClient client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      addTearDown(client.close);
      var now = 0;
      final remote = KomgaProgressRemote(client, 'account', now: () => now);
      int pageRequests() =>
          adapter.requests.where((r) => r.path.endsWith('/pages')).length;
      final id = book['id'] as String;

      final first = await remote.read(id);
      expect(pageRequests(), 1);
      final second = await remote.read(id);
      expect(pageRequests(), 1, reason: 'book-level fingerprint unchanged');
      expect(second.revision, first.revision);
      expect(second.pageIndex, first.pageIndex);

      book['fileLastModified'] = '2030-01-01T00:00:00Z';
      final changed = await remote.read(id);
      expect(pageRequests(), 2, reason: 'file change requires full manifest');
      expect(changed.revision, isNot(first.revision));

      now += 11 * 60 * 1000;
      await remote.read(id);
      expect(pageRequests(), 3, reason: 'memo expires');
    },
  );
}
