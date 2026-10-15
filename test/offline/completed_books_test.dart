import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/catalogue_fakes.dart';
import '../support/reader_fakes.dart';

void main() {
  test('offline series group by identity, use published art and retain removed metadata fallback', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DownloadStore(database, 'account', Directory('/unused'));
    final catalogue = CatalogueStore(database, 'account');
    ReaderManifest volume(
      String id,
      String? series, {
      String revision = 'first',
      String account = 'account',
    }) => ReaderManifest(
      accountId: account,
      bookId: id,
      revision: revision,
      title: 'Volume $id',
      seriesId: series,
      pages: readerManifest().pages,
    );
    for (final manifest in [
      volume('a1', 'series-a'),
      volume('a2', 'series-a'),
      volume('b1', 'series-b'),
      volume('orphan', null),
      volume('a1', 'series-a', revision: 'second'),
    ]) {
      await store.state(await store.enqueue(manifest), DownloadState.complete);
    }
    await store.enqueue(volume('pending', 'series-a'));
    final other = DownloadStore(database, 'other', store.directory);
    await other.state(
      await other.enqueue(volume('private', 'series-a', account: 'other')),
      DownloadState.complete,
    );
    await catalogue.stage('published', [
      entry(
        'series-a',
        kind: CatalogueKind.series,
        title: 'Same title',
        modified: 42,
      ),
      entry(
        'series-b',
        kind: CatalogueKind.series,
        title: 'Same title',
        modified: 43,
      ),
      entry('a2', seriesId: 'series-a', number: 1, modified: 5),
      entry('a1', seriesId: 'series-a', number: 2, modified: 6),
    ]);
    await catalogue.publish('published', DateTime.now(), () => true);
    var series = await store.completedSeries().first;
    expect(series, hasLength(3));
    final alpha = series.firstWhere((group) => group.item.id == 'series-a');
    expect(alpha.item.kind, CatalogueKind.series);
    expect(alpha.item.itemCount, 2);
    expect(alpha.books.map((book) => book.item.id), ['a2', 'a1']);
    expect(alpha.artwork.kind, CatalogueKind.series);
    expect(alpha.artwork.modified, 42);
    expect(
      series.where((group) => group.item.title == 'Same title'),
      hasLength(2),
    );
    expect(
      series.every(
        (group) => group.books.every(
          (book) => book.job.manifest.accountId == 'account',
        ),
      ),
      isTrue,
    );
    await catalogue.stage('staged', [
      entry('series-a', kind: CatalogueKind.series, title: 'Unpublished'),
    ]);
    expect(
      (await store.completedSeries().first)
          .firstWhere((group) => group.item.id == 'series-a')
          .item
          .title,
      'Same title',
    );
    await catalogue.publish('staged', DateTime.now(), () => true);
    series = await store.completedSeries().first;
    final missing = series.firstWhere((group) => group.item.id == 'series-b');
    expect(missing.item.canOpen, isTrue);
    expect(missing.books.single.item.id, 'b1');
    expect(missing.artwork.kind, CatalogueKind.series);
    expect(missing.item.title, 'Same title');
    expect(
      series.firstWhere((group) => group.item.id == 'unassigned').artwork.kind,
      CatalogueKind.book,
    );
    await store.state(missing.books.single.job.id, DownloadState.cancelled);
    expect(
      (await store.completedSeries().first).any(
        (group) => group.item.id == 'series-b',
      ),
      isFalse,
    );
  });
  test('offline catalogue joins published cover keys, retains missing books and excludes other accounts/unfinished jobs', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DownloadStore(database, 'account', Directory('/unused'));
    final catalogue = CatalogueStore(database, 'account');
    final alpha = ReaderManifest(
      accountId: 'account',
      bookId: 'alpha',
      revision: 'revision',
      title: 'Alpha',
      libraryId: 'manga',
      pages: readerManifest().pages,
    );
    final beta = ReaderManifest(
      accountId: 'account',
      bookId: 'beta',
      revision: 'revision',
      title: 'Beta',
      libraryId: 'ebooks',
      pages: readerManifest().pages,
    );
    for (final manifest in [alpha, beta]) {
      await store.state(await store.enqueue(manifest), DownloadState.complete);
    }
    await store.enqueue(readerManifest(account: 'account', book: 'queued'));
    final other = DownloadStore(database, 'other', store.directory);
    await other.state(
      await other.enqueue(readerManifest(account: 'other', book: 'alpha')),
      DownloadState.complete,
    );
    await catalogue.stage('first', [entry('alpha', modified: 42)]);
    await catalogue.publish('first', DateTime.utc(2026, 10, 12), () => true);
    var books = await store.completedBooks().first;
    expect(books.map((book) => book.item.id), ['alpha', 'beta']);
    expect(books.map((book) => book.item.libraryId), ['manga', 'ebooks']);
    expect(books.first.item.modified, 42);
    expect(books.last.item.modified, beta.revision.hashCode);
    expect(books.every((book) => book.item.canOpen), isTrue);
    await catalogue.stage('staged', [entry('alpha', modified: 99)]);
    expect((await store.completedBooks().first).first.item.modified, 42);
    await catalogue.publish('staged', DateTime.utc(2026, 10, 13), () => true);
    books = await store.completedBooks().first;
    expect(books.first.item.modified, 99);
    await catalogue.stage('removed', []);
    await catalogue.publish('removed', DateTime.utc(2026, 10, 14), () => true);
    expect((await store.completedBooks().first).first.item.canOpen, isTrue);
    await store.state(books.first.job.id, DownloadState.cancelled);
    expect((await store.completedBooks().first).single.item.id, 'beta');
  });
}
