import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/discovery_repository.dart';
import 'package:inkora/features/library/data/library_visibility_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  late AppDatabase database;
  late CatalogueStore store;
  final now = DateTime(2026, 10, 15);
  final items = [
    entry('library-a', kind: CatalogueKind.library),
    entry('library-b', kind: CatalogueKind.library),
    entry('series-a', kind: CatalogueKind.series),
    entry('series-b', kind: CatalogueKind.series, libraryId: 'library-b'),
    entry('book-a'),
    entry('book-b', libraryId: 'library-b', seriesId: 'series-b'),
    entry(
      'collection-a',
      kind: CatalogueKind.collection,
      members: ['series-a'],
    ),
    entry(
      'collection-b',
      kind: CatalogueKind.collection,
      members: ['series-b'],
    ),
    entry(
      'mixed',
      kind: CatalogueKind.collection,
      members: ['series-b', 'series-a'],
    ),
    entry('readlist-a', kind: CatalogueKind.readlist, members: ['book-a']),
    entry('readlist-b', kind: CatalogueKind.readlist, members: ['book-b']),
  ];
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = CatalogueStore(database, "server/user'quoted");
    await store.stage('first', items);
    await store.publish('first', now, () => true);
  });
  tearDown(() => database.close());

  test('visibility lookups and browse sorts use existing indexes', () async {
    for (final (order, index) in [
      ('e.sort_title ASC', 'catalogue_reading_title'),
      ('e.modified DESC', 'catalogue_reading_modified'),
    ]) {
      final rows = await database
          .customSelect(
            "EXPLAIN QUERY PLAN SELECT e.remote_id FROM catalogue_entries e WHERE e.account_id='account' AND e.generation='first' AND ${CatalogueStore.readingUnitsPredicate('e')} AND ${LibraryVisibilityStore.predicate('e')} ORDER BY $order, e.remote_id ASC, e.kind ASC LIMIT 30",
          )
          .get();
      final plan = rows.map((row) => row.read<String>('detail')).join('\n');
      expect(plan, contains(index));
      expect(plan, isNot(contains('USE TEMP B-TREE')));
      for (final alias in [
        'denied',
        'visible_members',
        'visible_child',
        'app_preferences',
      ]) {
        expect(plan, contains('SEARCH $alias USING'));
        expect(plan, isNot(contains('SCAN $alias')));
      }
    }
  });

  Future<List<String>> ids(CatalogueKind kind, {String search = ''}) async =>
      (await store.read(CatalogueQuery(kind: kind, search: search))).items
          .map((item) => item.id)
          .toList();

  test('default follows all accessible libraries, selection filters SQL counts, groups and search', () async {
    expect(await ids(CatalogueKind.library), ['library-a', 'library-b']);
    await store.visibility.save({'library-a'});
    expect(await ids(CatalogueKind.library), ['library-a']);
    expect(await ids(CatalogueKind.series), ['series-a']);
    expect(await ids(CatalogueKind.book, search: 'book-b'), isEmpty);
    expect(await ids(CatalogueKind.collection), ['collection-a', 'mixed']);
    expect(await ids(CatalogueKind.readlist), ['readlist-a']);
    final grouped = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        groupKind: CatalogueKind.collection,
        groupId: 'mixed',
        sort: CatalogueSort.sequence,
      ),
    );
    expect(grouped.items.map((item) => item.id), ['series-a']);
    expect(grouped.total, 1);
    expect(await store.item(CatalogueKind.series, 'series-b').first, isNull);
    expect((await store.overview().first)[CatalogueKind.book], 1);
    final raw = CatalogueStore(
      database,
      store.accountId,
      applyLibraryVisibility: false,
    );
    expect((await raw.watchAvailableLibraries().first).map((item) => item.id), [
      'library-a',
      'library-b',
    ]);
    await store.visibility.save({});
    for (final kind in CatalogueKind.values) {
      expect(await ids(kind), isEmpty);
    }
    await store.visibility.save(null);
    expect(await ids(CatalogueKind.book), ['book-a', 'book-b']);
  });

  test('account and server isolation survives reopening a database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'inkora-visibility-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/settings.sqlite');
    var persistent = AppDatabase(NativeDatabase(file));
    await LibraryVisibilityStore(persistent, 'server-a/user-a').save({'a'});
    await LibraryVisibilityStore(persistent, 'server-a/user-b').save({});
    await persistent.close();
    persistent = AppDatabase(NativeDatabase(file));
    expect(
      await LibraryVisibilityStore(persistent, 'server-a/user-a').watch().first,
      {'a'},
    );
    expect(
      await LibraryVisibilityStore(persistent, 'server-a/user-b').watch().first,
      isEmpty,
    );
    expect(
      await LibraryVisibilityStore(persistent, 'server-b/user-a').watch().first,
      isNull,
    );
    await persistent.close();
  });

  test('revoked libraries disappear from choices, old metadata and resume after publication', () async {
    await store.stage(
      'revoked',
      items
          .where(
            (item) => item.id != 'library-b' && item.libraryId != 'library-b',
          )
          .toList(),
    );
    await store.publish('revoked', now, () => true);
    expect(await ids(CatalogueKind.library), ['library-a']);
    expect(await ids(CatalogueKind.book), ['book-a']);
    final entries = items
        .where((item) => item.kind == CatalogueKind.book)
        .map(
          (item) =>
              ResumeEntry(item: item, pageIndex: 1, pageCount: 10, fraction: 0),
        )
        .toList();
    expect((await store.visibleResume(entries)).map((entry) => entry.item.id), [
      'book-a',
    ]);
    await store.visibility.save({'library-b'});
    expect(await ids(CatalogueKind.book), isEmpty);
    expect(await store.visibleResume(entries), isEmpty);
  });

  test(
    'all mode includes new libraries, explicit selection excludes them',
    () async {
      await store.stage('new', [
        ...items,
        entry('library-c', kind: CatalogueKind.library),
        entry('series-c', kind: CatalogueKind.series, libraryId: 'library-c'),
      ]);
      await store.publish('new', now, () => true);
      expect(await ids(CatalogueKind.library), hasLength(3));
      await store.visibility.save({'library-a', 'library-b'});
      expect(await ids(CatalogueKind.library), hasLength(2));
      expect(await ids(CatalogueKind.series), ['series-a', 'series-b']);
    },
  );

  test('discovery renews within the day after selection and restores after clearing it', () async {
    final discovery = DiscoveryRepository(store, clock: () => now);
    expect(
      (await discovery.readSections([]))
          .expand((page) => page.items)
          .map((item) => item.id)
          .toSet(),
      {'series-a', 'series-b'},
    );
    await store.visibility.save({'library-b'});
    expect(
      (await discovery.readSections([]))
          .expand((page) => page.items)
          .map((item) => item.id),
      ['series-b'],
    );
    await store.visibility.save({});
    expect(
      (await discovery.readSections([])).expand((page) => page.items),
      isEmpty,
    );
    await store.visibility.save(null);
    expect(
      (await discovery.readSections([]))
          .expand((page) => page.items)
          .map((item) => item.id)
          .toSet(),
      {'series-a', 'series-b'},
    );
  });

  test('unchanged selections and unrelated preferences do not emit catalogue publications', () async {
    var emissions = 0;
    final first = Completer<void>();
    final subscription = store.watchPublications().listen((_) {
      emissions++;
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    await store.visibility.save({'library-b', 'library-a'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions, 2);
    var writes = 0;
    final updates = database.tableUpdates().listen((_) => writes++);
    await store.visibility.save({'library-a', 'library-b'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes, 0);
    await LibraryVisibilityStore(database, 'another-account').save({});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions, 2);
    await updates.cancel();
    await subscription.cancel();
  });
}
