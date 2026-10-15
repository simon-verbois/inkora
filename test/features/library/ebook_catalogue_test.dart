import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/discovery_repository.dart';
import 'package:inkora/features/library/data/komga_catalogue_remote.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/catalogue_fakes.dart';

CatalogueItem ebook(
  String id, {
  String author = 'author',
  String type = 'application/epub+zip',
  int modified = 0,
}) => CatalogueItem(
  kind: CatalogueKind.book,
  id: id,
  title: 'Novel $id',
  seriesId: author,
  libraryId: 'mixed',
  modified: modified,
  metadata: CatalogueMetadata(
    mediaType: type,
    authors: const [CatalogueAuthor('A novelist', 'writer')],
  ),
);

void main() {
  late AppDatabase database;
  late CatalogueStore store;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = CatalogueStore(database, 'account');
    await store.stage('active', [
      entry('author', kind: CatalogueKind.series, libraryId: 'mixed'),
      ebook('a', modified: 10),
      ebook('b', type: 'application/pdf', modified: 20),
      entry(
        'comics',
        kind: CatalogueKind.series,
        libraryId: 'mixed',
        modified: 15,
      ),
      entry('comic-volume', seriesId: 'comics', libraryId: 'mixed'),
      entry('both', kind: CatalogueKind.series, libraryId: 'mixed'),
      ebook('c', author: 'both'),
      entry('raster', seriesId: 'both', libraryId: 'mixed'),
      entry('unknown', kind: CatalogueKind.series, libraryId: 'other'),
      entry(
        'collection',
        kind: CatalogueKind.collection,
        members: ['author', 'comics'],
      ),
      entry('readlist', kind: CatalogueKind.readlist, members: ['b', 'a']),
    ]);
    await store.publish('active', DateTime(2026, 10, 15), () => true);
  });
  tearDown(() => database.close());

  const browse = CatalogueQuery(kind: CatalogueKind.series, readingUnits: true);

  test(
    'library selection filters mixed ebook/comic projection before pagination',
    () async {
      await store.visibility.save({'mixed'});
      final selected = await store.read(browse);
      expect(selected.items.map((item) => item.identity).toSet(), {
        'book:a',
        'book:b',
        'book:c',
        'series:comics',
        'series:both',
      });
      expect(selected.total, 5);
      await store.visibility.save({'other'});
      expect((await store.read(browse)).items.map((item) => item.identity), [
        'series:unknown',
      ]);
    },
  );

  test(
    'MIME contract and snapshot roundtrip distinguish EPUB/PDF from raster',
    () async {
      for (final format in ['epub', 'pdf']) {
        final json = jsonDecode(
          await File('test/fixtures/komga/1.28.1/ebooks/$format-book.json')
              .readAsString(),
        );
        final item = parseCatalogueItem({
          ...json as Map<String, dynamic>,
          'name': 'Fixture',
          'deleted': false,
        }, CatalogueKind.book);
        expect(item.isEbook, isTrue);
        expect(
          CatalogueMetadata.fromJson(item.metadata.toJson()).mediaType,
          item.metadata.mediaType,
        );
      }
      expect(entry('image-book').isEbook, isFalse);
      expect(await store.needsMediaRefresh(), isFalse);
      expect(
        (await store.item(CatalogueKind.book, 'a').first)!.isEbook,
        isTrue,
      );
    },
  );

  test('mixed browse hides document-only authors, keeps raster series and separate books', () async {
    final page = await store.read(browse);
    expect(page.total, 6);
    expect(page.items.map((item) => item.identity).toSet(), {
      'book:a',
      'book:b',
      'book:c',
      'series:comics',
      'series:both',
      'series:unknown',
    });
    // Reader/library-default consumers still receive the unprojected data.
    expect(
      (await store.read(const CatalogueQuery(kind: CatalogueKind.series)))
          .total,
      4,
    );
    expect(browse, isNot(const CatalogueQuery(kind: CatalogueKind.series)));
  });

  test('library, search, recent order and offset pagination use the same reading units', () async {
    final page = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        readingUnits: true,
        libraryId: 'mixed',
        sort: CatalogueSort.recentlyUpdated,
        pageSize: 2,
      ),
    );
    expect(page.total, 5);
    expect(page.items.map((item) => item.identity), [
      'book:b',
      'series:comics',
    ]);
    final second = await store.read(browse, itemLimit: 2, itemOffset: 2);
    final full = await store.read(browse);
    expect(
      second.items.map((item) => item.identity),
      full.items.skip(2).take(2).map((item) => item.identity),
    );
    final search = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        readingUnits: true,
        search: 'Novel b',
      ),
    );
    expect(search.items.single.identity, 'book:b');
  });

  test('collection membership expands documents and readlist ordering stays book based', () async {
    final collection = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        readingUnits: true,
        groupKind: CatalogueKind.collection,
        groupId: 'collection',
        sort: CatalogueSort.sequence,
      ),
    );
    expect(collection.items.map((item) => item.identity), [
      'book:a',
      'book:b',
      'series:comics',
    ]);
    final list = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.book,
        groupKind: CatalogueKind.readlist,
        groupId: 'readlist',
        sort: CatalogueSort.sequence,
      ),
    );
    expect(list.items.map((item) => item.id), ['b', 'a']);
  });

  test(
    'staging and other accounts cannot change the published projection',
    () async {
      final other = CatalogueStore(database, 'other');
      await other.stage('private', [ebook('private')]);
      await other.publish('private', DateTime.now(), () => true);
      await store.stage('pending', [ebook('pending')]);
      final items = (await store.read(browse)).items;
      expect(
        items.any((item) => ['private', 'pending'].contains(item.id)),
        isFalse,
      );
      expect((await other.read(browse)).items.single.id, 'private');
    },
  );

  test('discovery includes independent books without excluding every book by the current author', () async {
    final repository = DiscoveryRepository(store);
    final pages = await repository.readSections([
      ResumeEntry(
        item: ebook('a'),
        pageIndex: 0,
        pageCount: 0,
        fraction: 0,
        raster: false,
        totalProgression: .25,
      ),
    ]);
    final items = pages.expand((page) => page.items).toList();
    expect(items.any((item) => item.identity == 'book:a'), isFalse);
    expect(items.any((item) => item.identity == 'book:b'), isTrue);
    expect(items.any((item) => item.identity == 'series:author'), isFalse);
    expect(items.map((item) => item.identity).toSet(), hasLength(items.length));
    expect(
      (await repository.readSections([]))
          .expand((page) => page.items)
          .map((item) => item.identity),
      items.map((item) => item.identity),
    );
  });

  test('book and series remote ID collisions remain distinct during discovery restoration', () async {
    await store.stage('collision', [
      ebook('shared'),
      entry('shared', kind: CatalogueKind.series, title: 'Novel shared'),
    ]);
    await store.publish('collision', DateTime.now(), () => true);
    final retained = await store.discoveryCandidates([
      'book:shared',
      'series:shared',
    ], sample: false);
    expect(retained.map((item) => item.identity).toSet(), {
      'book:shared',
      'series:shared',
    });
    final pages = [
      for (final page in [0, 1])
        await store.read(
          CatalogueQuery(
            kind: CatalogueKind.series,
            readingUnits: true,
            search: 'shared',
            pageSize: 1,
            page: page,
          ),
        ),
    ];
    expect(pages.map((page) => page.items.single.identity).toSet(), {
      'book:shared',
      'series:shared',
    });
  });

  test('older metadata forces one refresh even inside the normal freshness interval', () async {
    await database.customStatement(
      "UPDATE catalogue_entries SET descriptive_metadata='{}' WHERE account_id='account' AND kind='book'",
    );
    expect(await store.needsMediaRefresh(), isTrue);
    final remote = FakeCatalogueRemote()
      ..items[CatalogueKind.book] = [ebook('new')];
    final repository = CatalogueRepository(
      store,
      remote,
      now: () => DateTime(2026, 10, 15),
    );
    addTearDown(repository.close);
    await repository.refreshIfStale();
    expect(remote.calls, greaterThan(0));
    expect(await store.needsMediaRefresh(), isFalse);
    final calls = remote.calls;
    await repository.refreshIfStale();
    expect(remote.calls, calls);
  });

  test('format projection resolves children through indexes', () async {
    final plan = await database
        .customSelect(
          "EXPLAIN QUERY PLAN SELECT e.remote_id FROM catalogue_entries e WHERE e.account_id='account' AND e.generation='active' AND ${CatalogueStore.readingUnitsPredicate('e')}",
        )
        .get();
    final details = plan.map((row) => row.read<String>('detail')).join('\n');
    expect(details, contains('SEARCH child USING INDEX'));
    expect(details, isNot(contains('SCAN child')));
    for (final (order, index) in [
      ('e.sort_title ASC', 'catalogue_reading_title'),
      ('e.modified DESC', 'catalogue_reading_modified'),
    ]) {
      final sorted = await database
          .customSelect(
            "EXPLAIN QUERY PLAN SELECT e.remote_id FROM catalogue_entries e WHERE e.account_id='account' AND e.generation='active' AND ${CatalogueStore.readingUnitsPredicate('e')} ORDER BY $order, e.remote_id ASC, e.kind ASC LIMIT 30",
          )
          .get();
      final text = sorted.map((row) => row.read<String>('detail')).join('\n');
      expect(text, contains(index));
      expect(text, isNot(contains('USE TEMP B-TREE')));
    }
  });

  test('offline documents from the same author are separate and retain manifest format without catalogue', () async {
    final downloads = DownloadStore(database, 'account', Directory('/unused'));
    for (final (id, type, revision) in [
      ('first', 'application/epub+zip', '1'),
      ('second', 'application/pdf', '1'),
      ('first', 'application/epub+zip', '2'),
      ('raster-one', null, '1'),
      ('raster-two', null, '1'),
    ]) {
      final manifest = ReaderManifest(
        accountId: 'account',
        bookId: id,
        title: 'Saved $id',
        seriesId: 'absent-author',
        revision: revision,
        documentType: type,
        pages: [PageDimensions(1, 1)],
      );
      await downloads.state(
        await downloads.enqueue(manifest),
        DownloadState.complete,
      );
    }
    final shelf = await downloads.completedSeries().first;
    expect(shelf.map((group) => group.item.identity).toSet(), {
      'book:first',
      'book:second',
      'series:absent-author',
    });
    expect(
      shelf
          .where((group) => group.item.isEbook)
          .every((group) => group.books.length == 1),
      isTrue,
    );
    expect(
      shelf
          .singleWhere((group) => group.item.kind == CatalogueKind.series)
          .books,
      hasLength(2),
    );
  });
}
