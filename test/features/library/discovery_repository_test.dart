import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/discovery_repository.dart';
import 'package:inkora/features/library/domain/discovery.dart';

import '../../support/discovery_fakes.dart';

void main() {
  test(
    'genre affinity uses cached series when resume books omit genres',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = CatalogueStore(database, 'account');
      final now = DateTime(2026, 10, 12);
      await store.stage('metadata', [
        series('reading', genres: ['fantasy']),
        series('matching', genres: ['Fantasy']),
        series('other'),
      ]);
      await store.publish('metadata', now, () => true);
      final repository = DiscoveryRepository(store, clock: () => now);
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: repository.storageKey,
              payload: jsonEncode({
                'readingUnitsVersion': 1,
                ...DiscoveryMemory(
                  day: discoveryDay(now),
                  cycle: 0,
                  theme: DiscoveryTheme.similar,
                  ids: ['matching'],
                  recentIds: [],
                ).toJson(),
              }),
            ),
          );
      final page = await repository.read([reading('reading')]);
      expect(page.theme, DiscoveryTheme.similar);
      expect(page.items.single.id, 'matching');
    },
  );
  test('three sections survive reopen, stay fixed past midnight and rotate only on a new-day launch', () async {
    final directory = await Directory.systemTemp.createTemp(
      'inkora-discovery-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/catalogue.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    var store = CatalogueStore(database, 'account');
    var now = DateTime(2026, 10, 12);
    await store.stage('first', List.generate(120, (i) => series('series-$i')));
    await store.publish('first', now, () => true);
    List<String> ids(List<DiscoveryPage> pages) =>
        pages.expand((page) => page.items.map((item) => item.id)).toList();
    final first = await DiscoveryRepository(
      store,
      clock: () => now,
    ).readSections([]);
    final initial = ids(first);
    expect(first, hasLength(3));
    expect(initial, hasLength(30));
    expect(initial.toSet(), hasLength(30));
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    store = CatalogueStore(database, 'account');
    final repository = DiscoveryRepository(store, clock: () => now);
    expect(ids(await repository.readSections([])), initial);
    now = now.add(const Duration(days: 1));
    final concurrent = await Future.wait([
      repository.readSections([]),
      repository.readSections([]),
    ]);
    for (final pages in concurrent) {
      expect(
        ids(pages),
        initial,
      ); // The running app does not rotate at midnight.
    }
    final nextLaunch = DiscoveryRepository(store, clock: () => now);
    final daily = ids(await nextLaunch.readSections([]));
    expect(daily.toSet().intersection(initial.toSet()), isEmpty);
    expect(
      ids(await DiscoveryRepository(store, clock: () => now).readSections([])),
      daily,
    );
    final saved = jsonDecode(
      (await database.select(database.appPreferences).get()).single.payload,
    ) as Map<String, dynamic>;
    final sections = saved['sections'] as List;
    expect(sections, hasLength(3));
    expect(
      sections.every(
        (section) => section['day'] == '2026-10-13' && section['cycle'] == 0,
      ),
      isTrue,
    );
  });

  test('samples are bounded, retained IDs resolve, unpublished/other-account rows do not', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = CatalogueStore(database, "account'quoted");
    await store.stage('active', List.generate(800, (i) => series('series-$i')));
    await store.publish('active', DateTime(2026, 10, 12), () => true);
    await store.stage('unpublished', [series('unpublished')]);
    final other = CatalogueStore(database, 'other');
    await other.stage('other', [series('foreign')]);
    await other.publish('other', DateTime(2026, 10, 12), () => true);
    final pool = await store.discoveryCandidates(['series-799']);
    expect(pool, hasLength(401));
    expect(pool.first.id, 'series-799');
    expect(pool.every((item) => item.id.startsWith('series-')), isTrue);
    final retainedIds = List.generate(30, (i) => 'series-${770 + i}');
    final sharedPool = await store.discoveryCandidates(retainedIds);
    expect(sharedPool, hasLength(430));
    expect(
      sharedPool.take(30).map((item) => item.id).toSet(),
      retainedIds.toSet(),
    );
    final repository = DiscoveryRepository(
      store,
      clock: () => DateTime(2026, 10, 12),
    );
    final first = await repository.read([]);
    final excluded = first.items.first.id;
    final updated = await repository.read([reading(excluded)]);
    expect(updated.items.any((item) => item.id == excluded), isFalse);
    expect(updated.items, hasLength(9));
    final foreign = await DiscoveryRepository(other).read([]);
    expect(foreign.items.single.id, 'foreign');
    expect(
      (await database.select(database.appPreferences).get()),
      hasLength(2),
    );
    final noAccount = await DiscoveryRepository(
      CatalogueStore(database, 'absent'),
    ).read([]);
    expect(noAccount.items, isEmpty);
  });

  test(
    'initial discovery waits for usable metadata and adopts it once',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = CatalogueStore(database, 'account');
      final repository = DiscoveryRepository(
        store,
        clock: () => DateTime(2026, 10, 13),
      );
      expect(
        (await repository.readSections([])).expand((page) => page.items),
        isEmpty,
      );
      expect(await database.select(database.appPreferences).get(), isEmpty);
      await store.stage('first', [series('available')]);
      await store.publish('first', DateTime(2026, 10, 13), () => true);
      final ready = await repository.readSections([]);
      expect(ready.expand((page) => page.items).single.id, 'available');
      expect(
        await database.select(database.appPreferences).get(),
        hasLength(1),
      );
    },
  );

  test(
    'corrupt disposable memory recovers and publication drops removed picks',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = CatalogueStore(database, 'account');
      final repository = DiscoveryRepository(
        store,
        clock: () => DateTime(2026, 10, 12),
      );
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: repository.storageKey,
              payload: 'invalid json',
            ),
          );
      await store.stage('first', [
        series('available'),
        series('hidden', available: false),
      ]);
      await store.publish('first', DateTime(2026, 10, 12), () => true);
      expect((await repository.read([])).items.single.id, 'available');
      await store.stage('second', [series('replacement')]);
      await store.publish('second', DateTime(2026, 10, 12, 1), () => true);
      final replaced = await repository.watch([]).first;
      expect(
        replaced.items,
        isEmpty,
      ); // Removed picks wait until the next launch day.
      expect(replaced.theme, DiscoveryTheme.surprise);
    },
  );
}
