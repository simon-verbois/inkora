import 'dart:typed_data';
import 'dart:io';

import 'package:inkora/features/library/data/komga_catalogue_remote.dart';

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/settings/data/settings_transfer.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/raster_bookmarks.dart';
import 'package:inkora/reader/data/ebook_bookmarks.dart';
import 'package:inkora/reader/data/reading_history.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';

import '../../support/reader_fakes.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('raster bookmarks retain fractions, replace notes, isolate accounts and revisions', () async {
    final a = RasterBookmarks(db, 'a', 'book');
    await a.add(const RasterBookmark('v1', 2, .42, 'first'));
    await a.add(const RasterBookmark('v1', 2, .42, 'updated'));
    await a.add(const RasterBookmark('v2', 2, .42, 'new revision'));
    expect((await a.read()).map((b) => b.note), ['updated', 'new revision']);
    expect(await RasterBookmarks(db, 'b', 'book').read(), isEmpty);
    final bookmark = (await a.read()).first;
    expect(bookmark.locator.fraction, .42);
    await a.remove(bookmark);
    expect((await a.read()).single.revision, 'v2');
    expect(
      () => RasterBookmark.fromJson({
        'revision': 'v',
        'page': 0,
        'fraction': 2,
        'note': '',
      }),
      throwsFormatException,
    );
  });
  test('history records actual opens, deduplicates books, isolates clear and caps entries', () async {
    final a = ReadingHistoryStore(db, 'reader-account');
    await a.opened(readerManifest());
    await a.opened(readerManifest());
    expect(await a.recent(500), hasLength(1));
    await ReadingHistoryStore(db, 'b').opened(readerManifest(account: 'b'));
    for (var i = 0; i < 503; i++) {
      await a.opened(readerManifest(book: 'b-$i'));
    }
    expect(await a.recent(500), hasLength(500));
    await a.clear();
    expect(await a.recent(500), isEmpty);
    expect(await ReadingHistoryStore(db, 'b').recent(500), hasLength(1));
  });
  test('files round trip preferences and both bookmark kinds without setup, secrets or progress', () async {
    final ui = UiPreferencesStore(db);
    await ui.save(
      const UiPreferences(
        appearance: AppAppearance.ocean,
        setupCompleted: true,
        setupStep: 4,
      ),
    );
    await ReaderStore(db, 'a').saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(mode: ReadingMode.webtoon),
    );
    await RasterBookmarks(
      db,
      'a',
      'book',
    ).add(const RasterBookmark('v', 2, .4, 'Scene'));
    await RasterBookmarks(
      db,
      'other',
      'book',
    ).add(const RasterBookmark('v', 3, .7, 'Private'));
    await EbookBookmarks(db, 'a', 'epub').add(
      EbookLocator({
        'href': 'chapter.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {'progression': .5},
      }),
    );
    final transfer = SettingsTransfer(db, 'a');
    final bytes = await transfer.export();
    final value = await transfer.inspect(bytes);
    expect(value['bookmarks'], hasLength(2));
    expect(utf8.decode(bytes), isNot(contains('Private')));
    expect(utf8.decode(bytes), isNot(contains('setupCompleted')));
    await ui.save(const UiPreferences(setupCompleted: false));
    await transfer.apply(value);
    expect((await ui.watch().first).appearance, AppAppearance.ocean);
    expect((await ui.watch().first).setupCompleted, isFalse);
    await transfer.apply(value);
    expect(await RasterBookmarks(db, 'a', 'book').read(), hasLength(1));
    expect(await EbookBookmarks(db, 'a', 'epub').read(), hasLength(1));
    expect(await db.select(db.progressEvents).get(), isEmpty);
    await expectLater(
      SettingsTransfer(db, 'b').apply(value),
      throwsFormatException,
    );
  });
  test('portable file settings retain global preferences and reject unrelated versions', () async {
    await ReaderStore(db, 'a').saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(mode: ReadingMode.webtoon),
    );
    await ReaderStore(db, 'a').saveOverrides(
      SettingsScope.book,
      'book',
      const ReadingOverrides(mode: ReadingMode.manga),
    );
    final transfer = SettingsTransfer(db, 'a');
    final backup = await transfer.inspect(await transfer.export());
    final value = {
      ...backup,
      'portable': true,
      'preferences': [
        for (final preference in backup['preferences'] as List)
          if (preference['scope'] == 'global') preference,
      ],
      'bookmarks': <Object>[],
    }..remove('account');
    expect(value['bookmarks'], isEmpty);
    expect(value['preferences'], hasLength(1));
    await SettingsTransfer(db, 'b').apply(value);
    expect(
      (await ReaderStore(db, 'b').overrides(SettingsScope.global, '')).mode,
      ReadingMode.webtoon,
    );
    await expectLater(
      transfer.inspect(Uint8List.fromList(utf8.encode('https://example.com'))),
      throwsFormatException,
    );
    final invalid = {...value, 'version': 2};
    await expectLater(transfer.apply(invalid), throwsFormatException);
    expect(await db.select(db.readerPositions).get(), isEmpty);
  });
  test(
    'malformed entries roll back UI/settings and bookmark writes together',
    () async {
      final transfer = SettingsTransfer(db, 'a');
      final value = await transfer.inspect(await transfer.export());
      final broken = {
        ...value,
        'bookmarks': [
          {
            'kind': 'raster',
            'book': 'b',
            'values': [
              {'revision': 'v', 'page': -1, 'fraction': 0, 'note': ''},
            ],
          },
        ],
      };
      await expectLater(transfer.apply(broken), throwsFormatException);
      expect(await db.select(db.appPreferences).get(), isEmpty);
    },
  );
  test('read states filter before pagination and latest explicit unread overrides server complete', () async {
    final store = CatalogueStore(
      db,
      'reader-account',
      applyLibraryVisibility: false,
    );
    await store.stage('g', [
      const CatalogueItem(kind: CatalogueKind.series, id: 's', title: 'Series'),
      for (var i = 0; i < 6; i++)
        CatalogueItem(
          kind: CatalogueKind.book,
          id: 'b$i',
          title: 'Book $i',
          seriesId: 's',
          readingStatus: i < 3 ? ReadingStatus.completed : ReadingStatus.unread,
        ),
    ]);
    await store.publish('g', DateTime.now(), () => true);
    final unread = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.book,
        filters: MetadataFilters(readingStatus: ReadingStatus.unread),
        pageSize: 2,
      ),
    );
    expect(unread.total, 3);
    expect(unread.items.map((b) => b.id), ['b3', 'b4']);
    final manifest = readerManifest(book: 'b0');
    await ProgressStore(db, 'reader-account').save(
      manifest,
      manifestLocator(0),
      operation: ProgressOperation.markUnread,
    );
    final result = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.book,
        filters: MetadataFilters(readingStatus: ReadingStatus.unread),
      ),
    );
    expect(result.total, 4);
    final series = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.series,
        filters: MetadataFilters(readingStatus: ReadingStatus.inProgress),
      ),
    );
    expect(series.items, hasLength(1));
    await db.customStatement(
      'INSERT INTO reader_downloads(account_id,book_id,revision) VALUES (?,?,?)',
      ['reader-account', 'b3', 'v'],
    );
    final offline = await store.read(
      const CatalogueQuery(
        kind: CatalogueKind.book,
        filters: MetadataFilters(downloadedOnly: true),
      ),
    );
    expect(offline.items.single.id, 'b3');
  });
  test(
    'page saves do not wake state observers until classification changes',
    () async {
      final values = <List<BookReadingState>>[];
      final subscription = db
          .select(db.bookReadingStates)
          .watch()
          .listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final manifest = readerManifest(count: 6);
      final progress = ProgressStore(db, manifest.accountId);
      await progress.save(manifest, ReaderLocator(0));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final before = values.length;
      for (var page = 1; page < 5; page++) {
        await progress.save(manifest, ReaderLocator(page));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values.length, before);
      await progress.save(
        manifest,
        ReaderLocator(5),
        operation: ProgressOperation.complete,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(values.length, before + 1);
      expect(values.last.single.status, 'completed');
      await subscription.cancel();
    },
  );
  test('backup size/corruption checks precede all writes and merge overflow rolls back', () async {
    final transfer = SettingsTransfer(db, 'a');
    expect(
      () => transfer.inspect(Uint8List(SettingsTransfer.maxBytes + 1)),
      throwsFormatException,
    );
    await expectLater(
      transfer.inspect(Uint8List.fromList(utf8.encode('not-json'))),
      throwsFormatException,
    );
    final ui = UiPreferencesStore(db);
    await ui.save(const UiPreferences(appearance: AppAppearance.dark));
    for (var page = 0; page < 200; page++) {
      await RasterBookmarks(
        db,
        'a',
        'book',
      ).add(RasterBookmark('v', page, 0, ''));
    }
    final value = await transfer.inspect(await transfer.export());
    (value['ui'] as Map)['appearance'] = 'light';
    (value['bookmarks'] as List).single['values'] = [
      const RasterBookmark('v', 201, 0, 'new').toJson(),
    ];
    await expectLater(transfer.apply(value), throwsFormatException);
    expect((await ui.watch().first).appearance, AppAppearance.dark);
    expect(await RasterBookmarks(db, 'a', 'book').read(), hasLength(200));
  });
  test(
    'pinned Komga fixtures classify null, active and completed readProgress',
    () async {
      Map<String, dynamic> fixture(String name) => jsonDecode(
        File('test/fixtures/komga/1.28.1/$name').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        parseCatalogueItem(
          fixture('local-progress-reset.json'),
          CatalogueKind.book,
        ).readingStatus,
        ReadingStatus.unread,
      );
      expect(
        parseCatalogueItem(
          fixture('local-progress-first.json'),
          CatalogueKind.book,
        ).readingStatus,
        ReadingStatus.inProgress,
      );
      expect(
        parseCatalogueItem(
          fixture('local-progress-complete.json'),
          CatalogueKind.book,
        ).readingStatus,
        ReadingStatus.completed,
      );
    },
  );
}

// Helper keeps tests independent from viewport mechanics.
ReaderLocator manifestLocator(int page) => ReaderLocator(page);
