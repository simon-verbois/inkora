import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/features/library/data/saved_search_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/saved_catalogue_search.dart';

void main() {
  late AppDatabase database;
  late SavedSearchStore store;
  final query = CatalogueQuery(
    kind: CatalogueKind.book,
    libraryId: 'library',
    search: 'Author title',
    sort: CatalogueSort.recentlyUpdated,
    showUnavailable: false,
    filters: MetadataFilters.from(
      {
        CatalogueFacet.authors: 'Fixture Author',
        CatalogueFacet.genres: 'Fantasy',
        CatalogueFacet.mediaType: 'application/pdf',
      },
      readingStatus: ReadingStatus.inProgress,
      downloadedOnly: true,
    ),
  );
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = SavedSearchStore(database, 'a');
  });
  tearDown(() async => database.close());

  test('combined filters, text, scope and sorting round trip under the owning account', () async {
    await store.save(SavedCatalogueSearch('My reading', query));
    expect((await store.watch().first).single.query, query);
    expect(await SavedSearchStore(database, 'other').watch().first, isEmpty);
    final scoped = CatalogueQuery(
      kind: CatalogueKind.book,
      seriesId: 'series',
      groupKind: CatalogueKind.readlist,
      groupId: 'list',
      sort: CatalogueSort.sequence,
    );
    await store.save(SavedCatalogueSearch('List', scoped));
    expect((await store.watch().first).first.query, scoped);
    await store.remove('List');
    expect((await store.watch().first).single.name, 'My reading');
    await SavedSearchStore(database, 'other').remove('My reading');
    expect(await store.watch().first, hasLength(1));
  });

  test('duplicate writes do not emit, updates replace and malformed rows stay isolated', () async {
    await store.save(SavedCatalogueSearch('Good', query));
    final seen = <List<SavedCatalogueSearch>>[];
    final sub = store.watch().listen(seen.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await store.save(SavedCatalogueSearch('Good', query));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, hasLength(1));
    await database.customUpdate(
      'INSERT INTO reading_preferences(account_id,scope,scope_id,payload) VALUES(?,?,?,?)',
      variables: [
        const Variable('a'),
        const Variable(SavedSearchStore.scope),
        const Variable('Bad'),
        const Variable('{'),
      ],
      updates: {database.readingPreferences},
    );
    expect((await store.watch().first).single.name, 'Good');
    await store.save(
      const SavedCatalogueSearch(
        'Good',
        CatalogueQuery(kind: CatalogueKind.series),
      ),
    );
    expect((await store.watch().first).single.query.kind, CatalogueKind.series);
  });

  test('bounded names, query text, schema and collection prevent unbounded payloads', () async {
    await expectLater(
      store.save(SavedCatalogueSearch('x' * 81, query)),
      throwsFormatException,
    );
    await expectLater(
      store.save(
        const SavedCatalogueSearch(
          ' ',
          CatalogueQuery(kind: CatalogueKind.book),
        ),
      ),
      throwsFormatException,
    );
    await expectLater(
      store.save(
        SavedCatalogueSearch(
          'Long',
          CatalogueQuery(kind: CatalogueKind.book, search: 'x' * 513),
        ),
      ),
      throwsFormatException,
    );
    final invalid = SavedCatalogueSearch('Name', query).toJson()
      ..['status'] = 'invented';
    expect(
      () => SavedCatalogueSearch.fromJson(
        jsonDecode(jsonEncode(invalid)) as Map<String, dynamic>,
      ),
      throwsArgumentError,
    );
    for (var i = 0; i < SavedSearchStore.maximum; i++) {
      await store.save(SavedCatalogueSearch('$i', query));
    }
    await expectLater(
      store.save(SavedCatalogueSearch('Extra', query)),
      throwsStateError,
    );
    await store.save(SavedCatalogueSearch('0', query));
    await store.remove('0');
    await store.save(SavedCatalogueSearch('Extra', query));
    expect(await store.watch().first, hasLength(SavedSearchStore.maximum));
  });

  test(
    'recalled filters use current catalogue and library visibility',
    () async {
      final catalogue = CatalogueStore(database, 'a');
      await catalogue.stage('g', [
        const CatalogueItem(
          kind: CatalogueKind.library,
          id: 'library',
          title: 'Library',
        ),
        const CatalogueItem(
          kind: CatalogueKind.book,
          id: 'book',
          title: 'A fantasy book',
          libraryId: 'library',
          metadata: CatalogueMetadata(
            genres: ['Fantasy'],
            mediaType: 'application/pdf',
          ),
        ),
      ]);
      await catalogue.publish('g', DateTime.now(), () => true);
      await store.save(
        SavedCatalogueSearch(
          'Fantasy',
          CatalogueQuery(
            kind: CatalogueKind.book,
            filters: MetadataFilters.from({
              CatalogueFacet.genres: 'Fantasy',
              CatalogueFacet.mediaType: 'application/pdf',
            }),
          ),
        ),
      );
      final recalled = (await store.watch().first).single.query;
      expect((await catalogue.read(recalled)).items.single.id, 'book');
      await LibraryVisibilityStore(database, 'a').save({});
      expect((await catalogue.read(recalled)).items, isEmpty);
      expect(await store.watch().first, hasLength(1));
    },
  );

  test('saved searches survive a real SQLite close and reopen', () async {
    final root = await Directory.systemTemp.createTemp('inkora-saved-search-');
    final file = File('${root.path}/db');
    var db = AppDatabase(NativeDatabase(file));
    try {
      await SavedSearchStore(
        db,
        'a',
      ).save(SavedCatalogueSearch('Persisted', query));
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(
        (await SavedSearchStore(db, 'a').watch().first).single.query,
        query,
      );
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
