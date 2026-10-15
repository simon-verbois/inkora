import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/komga_catalogue_remote.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';

Map<String, dynamic> dto(String name) => jsonDecode(
  File('test/fixtures/komga/1.28.1/catalogue/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('deployed series metadata includes aggregated credits and series genres/links', () {
    final item = parseCatalogueItem(
      dto('metadata-series'),
      CatalogueKind.series,
    );
    expect(item.metadata.status, 'ENDED');
    expect(item.metadata.readingDirection, 'WEBTOON');
    expect(item.metadata.genres, hasLength(4));
    expect(item.metadata.authors, hasLength(5));
    expect(item.metadata.authors.map((author) => author.role).toSet(), {
      'writer',
      'penciller',
    });
    expect(item.metadata.links, hasLength(3));
    expect(item.searchText, contains('author 5'));
    final book = parseCatalogueItem(dto('metadata-book'), CatalogueKind.book);
    expect(book.metadata.authors, hasLength(5));
    expect(
      book.metadata.withSeries(item.metadata).genres,
      item.metadata.genres,
    );
    expect(
      book.metadata.withSeries(item.metadata).publisher,
      item.metadata.publisher,
    );
    expect(book.metadata.withSeries(item.metadata).isbn, book.metadata.isbn);
  });

  test('series tags merge with aggregate tags; blanks/duplicates normalize and unknown fields survive', () {
    final source = dto('metadata-series');
    final item = parseCatalogueItem({
      ...source,
      'metadata': {
        ...source['metadata'] as Map<String, dynamic>,
        'tags': [' Webtoon ', '', 'Fantasy'],
        'futureField': true,
      },
      'booksMetadata': {
        ...source['booksMetadata'] as Map<String, dynamic>,
        'tags': ['Webtoon', 'Other'],
      },
    }, CatalogueKind.series);
    expect(item.metadata.tags, ['Webtoon', 'Fantasy', 'Other']);
    expect(item.searchText, contains('other'));
    expect(
      CatalogueMetadata.fromJson(item.metadata.toJson()).toJson(),
      item.metadata.toJson(),
    );
    expect(CatalogueMetadata.fromJson({}).tags, isEmpty);
    for (final malformed in [
      {'tags': 'tag'},
      {
        'genres': [3],
      },
      {
        'authors': [
          {'name': 'Name', 'role': 7},
        ],
      },
      {
        'links': [
          {'label': 'Link', 'url': false},
        ],
      },
      {'ageRating': '13'},
    ]) {
      expect(
        () => CatalogueMetadata.fromJson(malformed),
        throwsFormatException,
      );
    }
  });

  test(
    'metadata reopens offline, remains on tombstones and cannot cross accounts',
    () async {
      final folder = await Directory.systemTemp.createTemp('inkora-metadata-');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/catalogue.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      final item = parseCatalogueItem(
        dto('metadata-series'),
        CatalogueKind.series,
      );
      var store = CatalogueStore(database, 'account-a');
      await store.stage('first', [item]);
      await store.publish('first', DateTime.now(), () => true);
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      addTearDown(database.close);
      store = CatalogueStore(database, 'account-a');
      const query = CatalogueQuery(kind: CatalogueKind.series);
      expect(
        (await store.read(query)).items.single.metadata.toJson(),
        item.metadata.toJson(),
      );
      await store.publish('removed', DateTime.now(), () => true);
      final retained = (await store.read(query)).items.single;
      expect(retained.canOpen, isFalse);
      expect(retained.metadata.toJson(), item.metadata.toJson());
      expect(
        (await CatalogueStore(database, 'account-b').read(query)).items,
        isEmpty,
      );
    },
  );

  test('v6 migration preserves catalogue, reading progress, downloads and preferences', () async {
    final folder = await Directory.systemTemp.createTemp('inkora-v6-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/database.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    final store = CatalogueStore(old, 'account');
    await store.stage('existing', [
      parseCatalogueItem(dto('metadata-book'), CatalogueKind.book),
    ]);
    await store.publish('existing', DateTime.now(), () => true);
    await old.customStatement(
      "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('account','book','revision',2,0.5)",
    );
    await old.customStatement(
      "INSERT INTO progress_events (account_id,book_id,sequence,revision,page_index,fraction,operation,state,page_count) VALUES ('account','book',1,'revision',2,0.5,'advance','queued',10)",
    );
    await old.customStatement(
      "INSERT INTO download_jobs (id,account_id,book_id,revision,manifest,state,reserved_bytes) VALUES ('job','account','book','revision','{}','complete',100)",
    );
    await old.customStatement(
      "INSERT INTO app_preferences VALUES ('appearance','light')",
    );
    await old.customStatement('DROP INDEX catalogue_document_books');
    await old.customStatement(
      'ALTER TABLE catalogue_entries DROP COLUMN descriptive_metadata',
    );
    await old.customStatement('PRAGMA user_version=6');
    await old.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final books = await CatalogueStore(
      upgraded,
      'account',
    ).read(const CatalogueQuery(kind: CatalogueKind.book));
    expect(books.items.single.title, 'Fixture');
    expect(books.items.single.metadata.tags, isEmpty);
    expect(
      (await upgraded.select(upgraded.readerPositions).getSingle()).fraction,
      .5,
    );
    expect(
      (await upgraded.select(upgraded.progressEvents).getSingle()).operation,
      'advance',
    );
    expect(
      (await upgraded.select(upgraded.downloadJobs).getSingle()).state,
      'complete',
    );
    expect(
      (await upgraded.select(upgraded.appPreferences).getSingle()).payload,
      'light',
    );
  });
}
