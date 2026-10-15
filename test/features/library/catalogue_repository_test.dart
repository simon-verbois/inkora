import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  late AppDatabase database;
  late CatalogueStore store;
  late FakeCatalogueRemote remote;
  late CatalogueRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = CatalogueStore(database, 'server-a/user-a');
    remote = FakeCatalogueRemote();
    repository = CatalogueRepository(store, remote);
  });
  tearDown(() async {
    repository.close();
    await database.close();
  });

  test('staged pages remain invisible; successful refresh publishes every category', () async {
    remote.items[CatalogueKind.book] = [entry('a'), entry('b'), entry('c')];
    remote.items[CatalogueKind.library] = [
      entry('library-a', kind: CatalogueKind.library),
    ];
    await store.stage('incomplete', [entry('never-published')]);
    expect(
      (await store.read(const CatalogueQuery(kind: CatalogueKind.book))).items,
      isEmpty,
    );
    await repository.refresh();
    final page = await store.read(
      const CatalogueQuery(kind: CatalogueKind.book, pageSize: 2),
    );
    expect(page.items.map((e) => e.id), ['a', 'b']);
    expect(page.total, 3);
    expect(page.lastUpdated, isNotNull);
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, page: 1, pageSize: 2),
      )).items.single.id,
      'c',
    );
    expect(
      await database.select(database.catalogueEntries).get(),
      hasLength(4),
    );
  });

  test(
    'failed later page retains snapshot and does not infer deletion',
    () async {
      remote.items[CatalogueKind.book] = [entry('a'), entry('b'), entry('c')];
      await repository.refresh();
      final before = await store.snapshot();
      remote.items[CatalogueKind.book] = [
        entry('a', title: 'changed'),
        entry('d'),
        entry('e'),
      ];
      remote.failKind = CatalogueKind.book;
      remote.failPage = 1;
      await repository.refresh();
      expect((await store.snapshot())!.generation, before!.generation);
      final page = await store.read(
        const CatalogueQuery(kind: CatalogueKind.book),
      );
      expect(page.items.map((e) => e.id), ['a', 'b', 'c']);
      expect(page.items.every((e) => e.available), isTrue);
      expect(
        await database.select(database.catalogueEntries).get(),
        hasLength(3),
      );
    },
  );

  test(
    'changed pagination totals and duplicate IDs never publish partial data',
    () async {
      remote.items[CatalogueKind.book] = [entry('a'), entry('b'), entry('c')];
      remote.onFetch = (kind, page) {
        if (kind == CatalogueKind.book && page == 1) {
          remote.items[kind]!.add(entry('d'));
        }
      };
      await repository.refresh();
      expect(await store.snapshot(), isNull);
      remote.onFetch = null;
      remote.items[CatalogueKind.book] = [entry('a'), entry('b'), entry('a')];
      await repository.refresh();
      expect(await store.snapshot(), isNull);
      expect(await database.select(database.catalogueEntries).get(), isEmpty);
    },
  );

  test('ordered lists keep missing metadata and retired members as explicit unavailable rows', () async {
    remote.items[CatalogueKind.book] = [
      entry('a', title: 'Alpha'),
      entry('b', title: 'Beta'),
    ];
    remote.items[CatalogueKind.readlist] = [
      entry(
        'list',
        kind: CatalogueKind.readlist,
        members: ['b', 'unknown', 'a'],
      ),
    ];
    remote.items[CatalogueKind.series] = [
      entry('series-a', kind: CatalogueKind.series),
      entry('series-b', kind: CatalogueKind.series),
    ];
    remote.items[CatalogueKind.collection] = [
      entry(
        'collection',
        kind: CatalogueKind.collection,
        members: ['series-b', 'series-a'],
      ),
    ];
    await repository.refresh();
    const query = CatalogueQuery(
      kind: CatalogueKind.book,
      groupKind: CatalogueKind.readlist,
      groupId: 'list',
      sort: CatalogueSort.sequence,
    );
    var page = await store.read(query);
    expect(page.items.map((e) => e.id), ['b', 'unknown', 'a']);
    expect(page.items[1].canOpen, isFalse);
    final collection = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        groupKind: CatalogueKind.collection,
        groupId: 'collection',
        sort: CatalogueSort.sequence,
      ),
    );
    expect(collection.items.map((e) => e.id), ['series-b', 'series-a']);
    remote.items[CatalogueKind.book] = [entry('a', title: 'Alpha')];
    remote.items[CatalogueKind.readlist] = [
      entry('list', kind: CatalogueKind.readlist, members: ['a', 'unknown']),
    ];
    await repository.refresh();
    page = await store.read(query);
    expect(page.items.map((e) => e.id), ['a', 'unknown', 'b']);
    expect(page.items.last.title, 'Beta');
    expect(page.items.last.membershipRemoved, isTrue);
    expect(page.items.last.canOpen, isFalse);
    final active = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.book,
        groupKind: CatalogueKind.readlist,
        groupId: 'list',
        sort: CatalogueSort.sequence,
        showUnavailable: false,
      ),
    );
    expect(active.items.map((e) => e.id), ['a']);
    // Restoring an item/member clears tombstone state without losing its identity.
    remote.items[CatalogueKind.book]!.add(entry('b', title: 'Beta'));
    remote.items[CatalogueKind.readlist] = [
      entry('list', kind: CatalogueKind.readlist, members: ['b', 'a']),
    ];
    await repository.refresh();
    expect((await store.read(query)).items.first.canOpen, isTrue);
  });

  test('removed and server-deleted entries retain metadata but disappear from active counts', () async {
    remote.items[CatalogueKind.book] = [entry('a'), entry('b')];
    await repository.refresh();
    remote.items[CatalogueKind.book] = [entry('a', deleted: true)];
    await repository.refresh();
    final all = await store.read(
      const CatalogueQuery(kind: CatalogueKind.book),
    );
    expect(all.total, 2);
    expect(all.items.every((e) => !e.canOpen), isTrue);
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, showUnavailable: false),
      )).total,
      0,
    );
  });

  test('search is local, literal, stable and scoped; sorting resets no remote state', () async {
    remote.items[CatalogueKind.book] = [
      entry('a', title: 'Zebra 100%_special', number: 3, modified: 10),
      entry('b', title: 'alpha hero', number: 1, modified: 30),
      entry(
        'c',
        title: 'Alpha history',
        libraryId: 'library-b',
        seriesId: 'series-b',
        number: 2,
        modified: 20,
      ),
    ];
    await repository.refresh();
    final calls = remote.calls;
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, search: 'ALPHA hero'),
      )).items.single.id,
      'b',
    );
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, search: '%_'),
      )).items.single.id,
      'a',
    );
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, search: "' OR 1=1 --"),
      )).items,
      isEmpty,
    );
    expect(
      (await store.read(
        const CatalogueQuery(kind: CatalogueKind.book, libraryId: 'library-a'),
      )).total,
      2,
    );
    expect(
      (await store.read(
        const CatalogueQuery(
          kind: CatalogueKind.book,
          sort: CatalogueSort.recentlyUpdated,
        ),
      )).items.map((e) => e.id),
      ['b', 'c', 'a'],
    );
    expect(
      (await store.read(
        const CatalogueQuery(
          kind: CatalogueKind.book,
          sort: CatalogueSort.titleDescending,
        ),
      )).items.first.id,
      'a',
    );
    expect(
      (await store.read(
        const CatalogueQuery(
          kind: CatalogueKind.book,
          seriesId: 'series-a',
          sort: CatalogueSort.sequence,
        ),
      )).items.map((e) => e.id),
      ['b', 'a'],
    );
    expect(remote.calls, calls);
  });

  test(
    'account namespaces isolate identical remote IDs and refreshes',
    () async {
      remote.items[CatalogueKind.book] = [entry('same', title: 'Account A')];
      await repository.refresh();
      final otherStore = CatalogueStore(database, 'server-a/user-b');
      expect(
        (await otherStore.read(const CatalogueQuery(kind: CatalogueKind.book)))
            .items,
        isEmpty,
      );
      await otherStore.stage('other', [entry('same', title: 'Account B')]);
      await otherStore.publish('other', DateTime.now(), () => true);
      expect(
        (await store.read(const CatalogueQuery(kind: CatalogueKind.book)))
            .items
            .single
            .title,
        'Account A',
      );
      expect(
        (await otherStore.read(const CatalogueQuery(kind: CatalogueKind.book)))
            .items
            .single
            .title,
        'Account B',
      );
    },
  );

  test('simultaneous refresh requests coalesce; session cancellation cannot publish', () async {
    remote.hold = Completer();
    remote.items[CatalogueKind.book] = [entry('a')];
    final first = repository.refresh();
    final second = repository.refresh();
    expect(identical(first, second), isTrue);
    repository.close();
    remote.hold!.complete();
    await first;
    expect(await store.snapshot(), isNull);
    expect(remote.cancelled, isTrue);
  });

  test('watch delivers local snapshot before a slow refresh and updates only on publication', () async {
    remote.items[CatalogueKind.book] = [entry('a')];
    await repository.refresh();
    final stream = StreamIterator(
      store.watch(const CatalogueQuery(kind: CatalogueKind.book)),
    );
    addTearDown(stream.cancel);
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.items.single.id, 'a');
    remote.hold = Completer();
    remote.items[CatalogueKind.book] = [entry('b')];
    final refreshing = repository.refresh();
    expect(
      (await store.read(const CatalogueQuery(kind: CatalogueKind.book)))
          .items
          .single
          .id,
      'a',
    );
    remote.hold!.complete();
    await refreshing;
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.items.map((e) => e.id), ['a', 'b']);
    expect(stream.current.items.first.canOpen, isFalse);
  });

  test('fresh restored snapshot avoids automatic network refresh', () async {
    final now = DateTime.utc(2026, 10, 11);
    await store.publish('restored', now, () => true);
    final cached = CatalogueRepository(
      store,
      remote,
      now: () => now.add(const Duration(minutes: 10)),
    );
    addTearDown(cached.close);
    await cached.refreshIfStale();
    expect(remote.calls, 0);
  });
  test(
    'account expiry immediately before commit rolls back snapshot publication',
    () async {
      await store.stage('before', [entry('a')]);
      await store.publish('before', DateTime.now(), () => true);
      await store.stage('after', [entry('b')]);
      var checks = 0;
      await expectLater(
        store.publish('after', DateTime.now(), () => ++checks < 3),
        throwsStateError,
      );
      expect((await store.snapshot())!.generation, 'before');
      expect(
        (await store.read(const CatalogueQuery(kind: CatalogueKind.book)))
            .items
            .single
            .id,
        'a',
      );
    },
  );

  test(
    'refresh prefetches the next remote page while the current page stages',
    () async {
      remote.items[CatalogueKind.book] = [
        for (var i = 0; i < 5; i++) entry('b$i'),
      ];
      final events = <String>[];
      final updates = database
          .tableUpdates(TableUpdateQuery.onTable(database.catalogueEntries))
          .listen((_) => events.add('staged'));
      addTearDown(updates.cancel);
      remote.onFetch = (kind, page) {
        if (kind == CatalogueKind.book) events.add('fetch $page');
      };
      await repository.refresh();
      // Page n+1 is requested before page n's staging write lands.
      expect(events.indexOf('fetch 1'), lessThan(events.indexOf('staged')));
      expect(events.where((e) => e.startsWith('fetch')), hasLength(3));
      final page = await store.read(
        const CatalogueQuery(kind: CatalogueKind.book),
      );
      expect(page.items.map((e) => e.id), ['b0', 'b1', 'b2', 'b3', 'b4']);
    },
  );
}
