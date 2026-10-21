import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';

void main() {
  test('metadata filters intersect before count/pagination and facets respect published account/library/search scope', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = CatalogueStore(database, 'a');
    CatalogueItem item(
      String id,
      String library, {
      String genre = 'Adventure',
      String publisher = 'Publisher',
    }) => CatalogueItem(
      kind: CatalogueKind.series,
      id: id,
      title: id,
      libraryId: library,
      metadata: CatalogueMetadata(
        genres: [genre],
        publisher: publisher,
        language: 'fr',
        status: 'ENDED',
        ageRating: 12,
        tags: ['Selected'],
        authors: const [CatalogueAuthor('Author', 'writer')],
      ),
    );
    await store.stage('published', [
      const CatalogueItem(kind: CatalogueKind.library, id: 'one', title: 'One'),
      const CatalogueItem(kind: CatalogueKind.library, id: 'two', title: 'Two'),
      for (var i = 0; i < 75; i++)
        item(
          'Book $i',
          'one',
          genre: i >= 65 ? 'Fantasy' : 'Adventure',
          publisher: i.isEven ? 'Even' : 'Odd',
        ),
      item('Other library', 'two', genre: 'Hidden genre'),
      item('Quoted', 'one', genre: "Reader's choice'; --"),
    ]);
    await store.publish('published', DateTime(2026), () => true);
    await store.stage('unpublished', [
      item('Never published', 'one', genre: 'Unpublished'),
    ]);
    final other = CatalogueStore(database, 'b');
    await other.stage('other', [
      item('Other account', 'one', genre: 'Private'),
    ]);
    await other.publish('other', DateTime(2026), () => true);
    final filters = MetadataFilters.from({
      CatalogueFacet.genres: 'Fantasy',
      CatalogueFacet.publisher: 'Even',
    });
    final query = CatalogueQuery(
      kind: CatalogueKind.series,
      readingUnits: true,
      libraryId: 'one',
      filters: filters,
      pageSize: 2,
    );
    final first = await store.read(query);
    expect(first.total, 5);
    // The filter sheet's result count uses the same scope without rows.
    expect(await store.count(query), 5);
    expect(
      await store.count(
        CatalogueQuery(
          kind: CatalogueKind.series,
          readingUnits: true,
          libraryId: 'one',
        ),
      ),
      (await store.read(
        CatalogueQuery(
          kind: CatalogueKind.series,
          readingUnits: true,
          libraryId: 'one',
        ),
      )).total,
    );
    expect(first.items, hasLength(2));
    final rest = await store.read(query, itemLimit: 3, itemOffset: 2);
    expect(rest.items, hasLength(3));
    expect({
      ...first.items.map((e) => e.id),
      ...rest.items.map((e) => e.id),
    }, hasLength(5));
    expect(
      [...first.items, ...rest.items].every((e) => filters.matches(e.metadata)),
      isTrue,
    );
    final options = await store.facets(query);
    expect(options[CatalogueFacet.genres], [
      'Adventure',
      'Fantasy',
      "Reader's choice'; --",
    ]);
    expect(options[CatalogueFacet.authors], ['Author']);
    expect(options[CatalogueFacet.ageRating], ['12']);
    final quote = await store.read(
      CatalogueQuery(
        kind: CatalogueKind.series,
        filters: MetadataFilters.from({
          CatalogueFacet.genres: "Reader's choice'; --",
        }),
      ),
    );
    expect(quote.items.single.id, 'Quoted');
    final searched = await store.facets(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        libraryId: 'one',
        search: 'Quoted',
      ),
    );
    expect(searched[CatalogueFacet.genres], ["Reader's choice'; --"]);
    await LibraryVisibilityStore(database, 'a').save({'one'});
    final visible = await store.facets(
      const CatalogueQuery(kind: CatalogueKind.series),
    );
    expect(visible[CatalogueFacet.genres], isNot(contains('Hidden genre')));
  });

  test(
    'ebook filters inherit absent series metadata and use exact format',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = CatalogueStore(database, 'a');
      await store.stage('g', const [
        CatalogueItem(
          kind: CatalogueKind.series,
          id: 'author',
          title: 'Author',
          libraryId: 'l',
          metadata: CatalogueMetadata(
            genres: ['Fantasy'],
            language: 'fr',
            authors: [CatalogueAuthor('Writer', 'writer')],
          ),
        ),
        CatalogueItem(
          kind: CatalogueKind.book,
          id: 'epub',
          title: 'EPUB',
          libraryId: 'l',
          seriesId: 'author',
          metadata: CatalogueMetadata(mediaType: 'application/epub+zip'),
        ),
        CatalogueItem(
          kind: CatalogueKind.book,
          id: 'pdf',
          title: 'PDF',
          libraryId: 'l',
          seriesId: 'author',
          metadata: CatalogueMetadata(
            mediaType: 'application/pdf',
            language: 'en',
          ),
        ),
      ]);
      await store.publish('g', DateTime(2026), () => true);
      final filters = MetadataFilters.from({
        CatalogueFacet.genres: 'Fantasy',
        CatalogueFacet.language: 'fr',
        CatalogueFacet.authors: 'Writer',
        CatalogueFacet.mediaType: 'application/epub+zip',
      });
      final query = CatalogueQuery(
        kind: CatalogueKind.series,
        readingUnits: true,
        filters: filters,
      );
      expect((await store.read(query)).items.single.id, 'epub');
      final options = await store.facets(query);
      expect(options[CatalogueFacet.mediaType], [
        'application/epub+zip',
        'application/pdf',
      ]);
      expect(options[CatalogueFacet.language], ['en', 'fr']);
      expect(
        query,
        CatalogueQuery(
          kind: CatalogueKind.series,
          readingUnits: true,
          filters: MetadataFilters.from(
            Map.fromEntries(filters.values.entries.toList().reversed),
          ),
        ),
      );
    },
  );
}
