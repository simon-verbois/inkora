import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/network/komga/komga_models.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/reading_history_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/reading_history.dart';
import 'package:inkora/features/library/presentation/progress_format.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';

const _fixtures = 'test/fixtures/komga/1.28.1';

Map<String, dynamic> historyFixture() =>
    jsonDecode(File('$_fixtures/history-books.json').readAsStringSync())
        as Map<String, dynamic>;

HistoryEntry server(
  String id,
  DateTime at, {
  ReadingStatus status = ReadingStatus.inProgress,
  double? ratio,
  String? seriesTitle = 'Server series',
}) => HistoryEntry(
  bookId: id,
  title: 'Server $id',
  at: at,
  source: HistorySource.server,
  seriesId: 'series-$id',
  seriesTitle: seriesTitle,
  number: 2,
  pageCount: 100,
  status: status,
  ratio: ratio,
);

HistoryEntry device(String id, DateTime at) => HistoryEntry(
  bookId: id,
  title: 'Device $id',
  at: at,
  source: HistorySource.device,
);

/// A fetch serving [pages] in order and recording requested page numbers.
final class FakeHistoryServer {
  FakeHistoryServer(this.pages);
  final List<List<HistoryEntry>> pages;
  final requested = <int>[];
  Completer<void>? gate;
  Object? failure;

  Future<CataloguePage<HistoryEntry>> call(
    int page,
    int size,
    CancelToken token,
  ) async {
    requested.add(page);
    await gate?.future;
    if (failure != null) throw failure!;
    if (token.isCancelled) throw StateError('cancelled');
    final items = pages[page];
    return CataloguePage<HistoryEntry>.fromJson({
      'content': items,
      'number': page,
      'size': size,
      'totalElements': pages.fold<int>(0, (n, p) => n + p.length),
      'totalPages': pages.length,
      'last': page == pages.length - 1,
      'numberOfElements': items.length,
    }, (value) => value! as HistoryEntry);
  }
}

Future<void> opened(
  AppDatabase database,
  String account,
  String book,
  DateTime at, {
  String title = 'Opened',
}) => database.customInsert(
  'INSERT OR REPLACE INTO reading_history (account_id, book_id, title, opened_at) VALUES (?, ?, ?, ?)',
  variables: [
    Variable(account),
    Variable(book),
    Variable(title),
    Variable(at.toUtc()),
  ],
  updates: {database.readingHistory},
);

void main() {
  final now = DateTime.utc(2026, 10, 20, 12);

  group('merge', () {
    test('keeps one entry per book with the newest timestamp', () {
      final merged = mergeReadingHistory(
        [
          device('a', now.subtract(const Duration(hours: 1))),
          device('b', now.subtract(const Duration(days: 3))),
          device('c', now),
        ],
        [
          server('a', now.subtract(const Duration(hours: 5)), ratio: .5),
          server('b', now.subtract(const Duration(hours: 2)), ratio: .25),
          server('d', now.subtract(const Duration(days: 9))),
          // A duplicate server row keeps its newest copy.
          server('d', now.subtract(const Duration(days: 8))),
        ],
      );
      expect([for (final e in merged) e.bookId], ['c', 'a', 'b', 'd']);
      final a = merged[1];
      // Device open is newer: its time and source win, server metadata stays.
      expect(a.source, HistorySource.device);
      expect(a.at, now.subtract(const Duration(hours: 1)));
      expect(a.seriesTitle, 'Server series');
      expect(a.ratio, .5);
      // Server progress is newer than the device open.
      expect(merged[2].source, HistorySource.server);
      expect(merged[2].title, 'Server b');
      expect(merged[3].at, now.subtract(const Duration(days: 8)));
    });

    test('equal timestamps keep the server entry and a stable order', () {
      final merged = mergeReadingHistory(
        [device('b', now), device('a', now)],
        [server('b', now)],
      );
      expect([for (final e in merged) e.bookId], ['a', 'b']);
      expect(merged[1].source, HistorySource.server);
    });

    test('day groups follow local calendar days', () {
      final local = DateTime(2026, 10, 20, 9);
      expect(
        historyPeriod(DateTime(2026, 10, 20, 0, 5), local),
        HistoryPeriod.today,
      );
      expect(
        historyPeriod(DateTime(2026, 10, 19, 23, 59), local),
        HistoryPeriod.yesterday,
      );
      expect(
        historyPeriod(DateTime(2026, 10, 14, 8), local),
        HistoryPeriod.thisWeek,
      );
      expect(
        historyPeriod(DateTime(2026, 10, 13, 22), local),
        HistoryPeriod.earlier,
      );
      // Future (clock skew) entries count as today.
      expect(historyPeriod(DateTime(2026, 10, 21), local), HistoryPeriod.today);
    });

    test('history progress uses the shared formatter', () {
      final strings = AppStrings('en');
      expect(
        formatHistoryProgress(strings, server('a', now, ratio: .92)).label,
        'Server a · 92 %',
      );
      expect(
        formatHistoryProgress(
          strings,
          server('a', now, status: ReadingStatus.completed),
        ).label,
        'Server a · Read',
      );
      expect(
        formatHistoryProgress(strings, server('a', now)).label,
        'Server a · In progress',
      );
    });
  });

  group('Komga contract', () {
    test('the 1.28.1 OpenAPI accepts repeated read_status and sort values', () {
      final schema = jsonDecode(
        File('$_fixtures/openapi.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final parameters =
          ((schema['paths'] as Map)['/api/v1/books'] as Map)['get']
              as Map<String, dynamic>;
      Map<String, dynamic> parameter(String name) =>
          (parameters['parameters'] as List)
                  .cast<Map<String, dynamic>>()
                  .singleWhere((p) => p['name'] == name)['schema']
              as Map<String, dynamic>;
      expect(parameter('read_status')['type'], 'array');
      expect(
        (parameter('read_status')['items'] as Map)['enum'],
        containsAll(['IN_PROGRESS', 'READ']),
      );
      expect(parameter('sort')['type'], 'array');
    });

    test('the captured history page parses newest progress first', () {
      final page = CataloguePage<HistoryEntry>.fromJson(
        historyFixture(),
        parseServerHistoryEntry,
      );
      expect(page.items, hasLength(8));
      expect(page.last, isFalse);
      final times = [for (final e in page.items) e.at];
      expect(times, [...times]..sort((a, b) => b.compareTo(a)));
      expect(page.items.last.status, ReadingStatus.completed);
      expect(page.items.last.ratio, 1);
      expect(page.items.first.isEbook, isTrue);
      // EPUB positions are not page ratios; DIVINA pages are.
      expect(page.items.first.ratio, isNull);
      expect(page.items[1].ratio, isNotNull);
      expect(page.items.every((e) => e.source == HistorySource.server), isTrue);
    });

    test('the client requests both statuses sorted by progress date', () async {
      final adapter = FixtureAdapter((_) => jsonResponse(historyFixture()));
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      addTearDown(client.close);
      final page = await client.cataloguePage(
        'book',
        parseServerHistoryEntry,
        page: 0,
        size: 20,
        history: true,
        parseInBackground: true,
      );
      expect(page.items, hasLength(8));
      final uri = adapter.requests.single.uri;
      expect(uri.path, endsWith('/api/v1/books'));
      expect(uri.queryParametersAll['read_status'], ['IN_PROGRESS', 'READ']);
      expect(uri.queryParameters['sort'], 'readProgress.lastModified,desc');
      expect(
        () => client.cataloguePage(
          'book',
          parseServerHistoryEntry,
          history: true,
          inProgress: true,
        ),
        throwsArgumentError,
      );
    });
  });

  group('repository', () {
    late AppDatabase database;
    late CatalogueStore catalogue;
    var current = true;
    setUp(() {
      current = true;
      database = AppDatabase(NativeDatabase.memory());
      catalogue = CatalogueStore(database, 'account');
    });
    tearDown(() => database.close());

    ReadingHistoryRepository repository(
      FakeHistoryServer server, {
      CatalogueStore? store,
      int maxPages = 10,
    }) => ReadingHistoryRepository(
      store ?? catalogue,
      fetch: server.call,
      isCurrent: () => current,
      pageSize: 2,
      maxPages: maxPages,
    );

    test('merges device opens with cached server progress', () async {
      final remote = FakeHistoryServer([
        [
          HistoryEntry(
            bookId: 'shared',
            title: 'Shared',
            at: now.subtract(const Duration(hours: 4)),
            source: HistorySource.server,
            status: ReadingStatus.completed,
            ratio: 1,
          ),
          HistoryEntry(
            bookId: 'remote',
            title: 'Remote',
            at: now.subtract(const Duration(days: 2)),
            source: HistorySource.server,
          ),
        ],
      ]);
      final history = repository(remote);
      addTearDown(history.close);
      await opened(database, 'account', 'shared', now, title: 'Local');
      await opened(
        database,
        'account',
        'local',
        now.subtract(const Duration(days: 1)),
      );
      await history.refresh();
      final view = await history.read();
      expect(
        [for (final e in view.entries) e.bookId],
        ['shared', 'local', 'remote'],
      );
      expect(view.deviceCount, 2);
      expect(view.entries.first.source, HistorySource.device);
      expect(view.entries.first.title, 'Shared');
      expect(view.more, isFalse);
    });

    test('isolates accounts: caches and device opens never mix', () async {
      final a = repository(
        FakeHistoryServer([
          [server('a-book', now)],
        ]),
      );
      final otherStore = CatalogueStore(database, 'other');
      final b = repository(
        FakeHistoryServer([
          [server('b-book', now)],
        ]),
        store: otherStore,
      );
      addTearDown(a.close);
      addTearDown(b.close);
      await opened(database, 'other', 'b-local', now);
      await a.refresh();
      await b.refresh();
      expect([for (final e in (await a.read()).entries) e.bookId], ['a-book']);
      expect([
        for (final e in (await b.read()).entries) e.bookId,
      ], unorderedEquals(['b-book', 'b-local']));
      expect(a.key, isNot(b.key));
    });

    test('offline keeps local opens and the last cached server page', () async {
      final remote = FakeHistoryServer([
        [server('cached', now.subtract(const Duration(days: 1)))],
      ]);
      final history = repository(remote);
      addTearDown(history.close);
      await history.refresh();
      remote.failure = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
      await opened(database, 'account', 'local', now);
      await history.refresh();
      expect(
        [for (final e in (await history.read()).entries) e.bookId],
        ['local', 'cached'],
      );
    });

    test('unchanged refreshes do not write and requests coalesce', () async {
      final remote = FakeHistoryServer([
        [server('a', now), server('b', now)],
        [server('c', now)],
      ]);
      final history = repository(remote);
      addTearDown(history.close);
      var writes = -1;
      final ready = Completer<void>();
      final watch = watchTables(database, {database.appPreferences}).listen((
        _,
      ) {
        writes++;
        if (!ready.isCompleted) ready.complete();
      });
      addTearDown(watch.cancel);
      await ready.future;
      remote.gate = Completer<void>();
      final first = history.refresh();
      final second = history.refresh();
      remote.gate!.complete();
      await Future.wait([first, second]);
      expect(remote.requested, [0]);
      await pumpEventQueue();
      expect(writes, 1);
      await history.refresh();
      await pumpEventQueue();
      expect(remote.requested, [0, 0]);
      expect(writes, 1);
    });

    test('load more appends the next page until the last one', () async {
      final remote = FakeHistoryServer([
        [server('a', now), server('b', now)],
        [server('b', now), server('c', now)],
        [server('d', now)],
      ]);
      final history = repository(remote, maxPages: 2);
      addTearDown(history.close);
      await history.refresh();
      expect((await history.read()).more, isTrue);
      await history.loadMore();
      final view = await history.read();
      // The page cap stops pagination; duplicates across pages collapse.
      expect(view.more, isFalse);
      expect([for (final e in view.entries) e.bookId], ['a', 'b', 'c']);
      await history.loadMore();
      expect(remote.requested, [0, 1]);
      // A refresh restarts from the newest page.
      await history.refresh();
      expect((await history.read()).entries, hasLength(2));
    });

    test('a result arriving after an account switch is discarded', () async {
      final remote = FakeHistoryServer([
        [server('a', now)],
      ]);
      final history = repository(remote);
      addTearDown(history.close);
      remote.gate = Completer<void>();
      final refresh = history.refresh();
      current = false;
      remote.gate!.complete();
      await refresh;
      current = true;
      expect((await history.read()).entries, isEmpty);
    });

    test(
      'device opens use catalogue metadata and local reading state',
      () async {
        await catalogue.stage('g', [
          entry('series-a', kind: CatalogueKind.series, title: 'Moonlit'),
          entry('book-a', title: 'Moonlit 3', number: 3),
          entry('hidden-book', title: 'Hidden', libraryId: 'gone'),
          entry('gone', kind: CatalogueKind.library, available: false),
        ]);
        await catalogue.publish('g', now, () => true);
        await opened(database, 'account', 'book-a', now, title: 'File name');
        await opened(database, 'account', 'hidden-book', now);
        await database.customInsert(
          'INSERT INTO reader_positions (account_id, book_id, revision, page_index, fraction) VALUES (?, ?, ?, ?, ?)',
          variables: [
            const Variable('account'),
            const Variable('book-a'),
            const Variable('r'),
            const Variable(4),
            const Variable(0.0),
          ],
        );
        final history = ReadingHistoryRepository(
          catalogue,
          isCurrent: () => true,
        );
        final view = await history.read();
        // The revoked library's book is hidden; the counted open remains.
        expect(view.deviceCount, 2);
        final book = view.entries.single;
        expect(book.title, 'Moonlit 3');
        expect(book.seriesTitle, 'Moonlit');
        expect(book.number, 3);
        expect(book.status, ReadingStatus.inProgress);
      },
    );
  });
}
