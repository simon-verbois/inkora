import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/application/catalogue_feed.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  test('continuous local windows grow without duplicates, preserve order and replace published generations atomically', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = CatalogueStore(database, 'account');
    final books = List.generate(
      145,
      (i) => entry('id-$i', title: 'Book ${i.toString().padLeft(3, '0')}'),
    );
    await store.stage('one', books);
    await store.publish('one', DateTime.now(), () => true);
    final feed = CatalogueFeed(
      store,
      const CatalogueQuery(kind: CatalogueKind.book),
    );
    addTearDown(() async {
      feed.close();
      await database.close();
    });
    var state = await feed.stream.firstWhere((s) => !s.loading);
    expect(state.page.items, hasLength(60));
    expect(state.page.total, 145);
    feed.loadMore();
    feed.loadMore();
    state = await feed.stream.firstWhere(
      (s) => !s.loading && s.page.items.length == 120,
    );
    expect(state.page.items.map((i) => i.id).toSet(), hasLength(120));
    expect(state.page.items.last.id, 'id-119');
    feed.loadMore();
    state = await feed.stream.firstWhere(
      (s) => !s.loading && s.page.items.length == 145,
    );
    expect(state.hasMore, false);
    await store.stage('two', [
      entry('fresh', title: 'A new book'),
      ...books.take(5),
    ]);
    expect(feed.state.page.total, 145);
    await store.publish('two', DateTime.now(), () => true);
    state = await feed.stream.firstWhere(
      (s) => s.page.items.first.id == 'fresh',
    );
    expect(
      state.page.items.map((i) => i.id).toSet(),
      hasLength(state.page.items.length),
    );
    final other = CatalogueFeed(
      CatalogueStore(database, 'other'),
      const CatalogueQuery(kind: CatalogueKind.book),
    );
    addTearDown(other.close);
    expect(
      (await other.stream.firstWhere((s) => !s.loading)).page.items,
      isEmpty,
    );
  });
}
