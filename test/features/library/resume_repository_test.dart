import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/resume_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/connection_fakes.dart';
import '../../support/catalogue_fakes.dart';
import '../../support/reader_fakes.dart';

Map<String, dynamic> fixture() => jsonDecode(
  File('test/fixtures/komga/1.28.1/resume-books.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> onDeckFixture() {
  final result = jsonDecode(
    File('test/fixtures/komga/1.28.1/on-deck-books.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final book = (result['content'] as List).single as Map<String, dynamic>;
  book['id'] = 'deck-book';
  book['seriesId'] = 'deck-series';
  return result;
}

Map<String, dynamic> emptyShelf() => {
  ...fixture(),
  'content': <Object?>[],
  'totalElements': 0,
  'totalPages': 0,
  'numberOfElements': 0,
};

void main() {
  late AppDatabase database;
  late ResumeRepository repository;
  late FixtureAdapter adapter;
  late CatalogueStore catalogue;
  var current = true;
  setUp(() {
    current = true;
    database = AppDatabase(NativeDatabase.memory());
    catalogue = CatalogueStore(database, 'account');
    adapter = FixtureAdapter(
      (options) => jsonResponse(
        options.uri.path.endsWith('/ondeck') ? emptyShelf() : fixture(),
      ),
    );
    repository = ResumeRepository(
      catalogue,
      fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
      isCurrent: () => current,
    );
  });
  tearDown(() async {
    repository.close();
    repository.client.close();
    await database.close();
  });

  test(
    'selection updates cached resume and on-deck without another request',
    () async {
      adapter = FixtureAdapter(
        (options) => jsonResponse(
          options.uri.path.endsWith('/ondeck') ? onDeckFixture() : fixture(),
        ),
      );
      repository.client.close();
      repository = ResumeRepository(
        catalogue,
        fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
        isCurrent: () => true,
      );
      await repository.refresh();
      final requests = adapter.requests.length;
      final filtered = repository.watch().firstWhere(
        (entries) =>
            entries.isNotEmpty &&
            entries.every((entry) => entry.item.libraryId == 'fixture-id-6'),
      );
      await catalogue.visibility.save({'fixture-id-6'});
      expect(await filtered, hasLength(3));
      await catalogue.visibility.save({});
      expect(await repository.watch().first, isEmpty);
      await catalogue.visibility.save(null);
      expect(await repository.watch().first, hasLength(7));
      expect(adapter.requests, hasLength(requests));
      expect(await database.select(database.readerPositions).get(), isEmpty);
      expect(await database.select(database.progressEvents).get(), isEmpty);
    },
  );

  test('server shelf includes all six books without local manifests, including EPUB page zero', () async {
    await repository.refresh();
    final entries = await repository.watch().first;
    expect(entries, hasLength(6));
    expect(entries.first.pageIndex, 26);
    expect(entries.where((e) => !e.raster), hasLength(2));
    expect(entries[4].pageKnown, false);
    expect(entries[4].progress, 0);
    expect(adapter.requests.first.uri.path, '/komga/api/v1/books');
    expect(
      adapter.requests.first.queryParameters['read_status'],
      'IN_PROGRESS',
    );
    expect(
      adapter.requests.first.queryParameters['sort'],
      'readProgress.lastModified,desc',
    );
    expect(await database.select(database.readerManifests).get(), isEmpty);
    expect(await database.select(database.progressEvents).get(), isEmpty);
    final other = ResumeRepository(
      CatalogueStore(database, 'other'),
      repository.client,
      isCurrent: () => true,
    );
    addTearDown(other.close);
    expect(await other.watch().first, isEmpty);
  });

  test('offline failure keeps cache, a successful empty response removes completed server books', () async {
    await repository.refresh();
    repository.close();
    final cached = ResumeRepository(
      catalogue,
      fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((_) => jsonResponse({}, status: 503)),
      ),
      isCurrent: () => true,
    );
    addTearDown(cached.close);
    addTearDown(cached.client.close);
    await cached.refresh();
    expect(await cached.watch().first, hasLength(6));
    final empty = ResumeRepository(
      catalogue,
      fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter(
          (_) => jsonResponse({
            ...fixture(),
            'content': <Object?>[],
            'totalElements': 0,
            'totalPages': 0,
            'numberOfElements': 0,
          }),
        ),
      ),
      isCurrent: () => true,
    );
    addTearDown(empty.close);
    addTearDown(empty.client.close);
    await empty.refresh();
    expect(await empty.watch().first, isEmpty);
  });

  test(
    'series labels use only published account metadata and update offline',
    () async {
      final book = (fixture()['content'] as List).first;
      final seriesId = book['seriesId'] as String;
      final other = CatalogueStore(database, 'other');
      await other.stage('other', [
        entry(seriesId, kind: CatalogueKind.series, title: 'Other account'),
      ]);
      await other.publish('other', DateTime.now(), () => true);
      await repository.refresh();
      expect((await repository.watch().first).first.seriesTitle, 'Fixture');
      expect((await repository.watch().first).first.item.seriesId, seriesId);
      await catalogue.stage('first', [
        entry(seriesId, kind: CatalogueKind.series, title: 'Published series'),
      ]);
      expect((await repository.watch().first).first.seriesTitle, 'Fixture');
      await catalogue.publish('first', DateTime.now(), () => true);
      final initial = await repository.watch().first;
      expect(initial.first.seriesTitle, 'Published series');
      expect(initial.first.item.title, 'Fixture');
      expect(initial.first.pageIndex, 26);
      await catalogue.stage('second', [
        entry(seriesId, kind: CatalogueKind.series, title: 'Renamed series'),
      ]);
      final update = repository.watch().firstWhere(
        (entries) => entries.first.seriesTitle == 'Renamed series',
      );
      await catalogue.publish('second', DateTime.now(), () => true);
      expect((await update).first.seriesTitle, 'Renamed series');
      expect(adapter.requests, hasLength(2));
    },
  );

  test('on-deck joins the shelf, survives offline and becomes local reading when started', () async {
    var offline = false;
    adapter = FixtureAdapter(
      (options) => offline
          ? jsonResponse({}, status: 503)
          : jsonResponse(
              options.uri.path.endsWith('/ondeck')
                  ? onDeckFixture()
                  : fixture(),
            ),
    );
    repository.close();
    repository.client.close();
    repository = ResumeRepository(
      catalogue,
      fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
      isCurrent: () => current,
    );
    await repository.refresh();
    final entries = await repository.watch().first;
    expect(entries, hasLength(7));
    final next = entries.last;
    expect(next.onDeck, true);
    expect(next.pageCount, 198);
    expect(next.progress, 0);
    expect(next.seriesTitle, 'Fixture');
    expect(adapter.requests.last.uri.path, '/komga/api/v1/books/ondeck');
    expect(adapter.requests.last.queryParameters, {'page': 0, 'size': 200});
    offline = true;
    await repository.refresh(force: true);
    expect((await repository.watch().first).last.onDeck, true);
    await catalogue.stage('started', [next.item]);
    await catalogue.publish('started', DateTime.now(), () => true);
    final manifest = readerManifest(account: 'account', book: next.item.id);
    await ReaderStore(database, 'account').saveManifest(manifest);
    final progress = ProgressStore(database, 'account');
    await progress.save(manifest, ReaderLocator(1, .5));
    final started = (await repository.watch().first).last;
    expect(started.onDeck, false);
    expect(started.seriesTitle, 'Fixture');
    expect(started.pageIndex, 1);
    expect(started.fraction, .5);
    await progress.save(
      manifest,
      ReaderLocator(1),
      operation: ProgressOperation.complete,
    );
    expect(
      (await repository.watch().first).any(
        (entry) => entry.item.id == next.item.id,
      ),
      false,
    );
  });

  test('on-deck pagination is complete and malformed or forbidden refresh retains both shelves', () async {
    var mode = 'valid';
    adapter = FixtureAdapter((options) {
      if (!options.uri.path.endsWith('/ondeck')) return jsonResponse(fixture());
      if (mode == 'forbidden') return jsonResponse({}, status: 403);
      final page = options.queryParameters['page'] as int;
      final data = onDeckFixture();
      final original = (data['content'] as List).single as Map<String, dynamic>;
      return jsonResponse({
        ...data,
        'content': [
          {
            ...original,
            'id': 'deck-${mode == 'duplicate' ? 0 : page}',
            'seriesId': 'deck-series-$page',
          },
        ],
        'number': page,
        'size': 1,
        'totalPages': 2,
        'totalElements': 2,
        'last': mode == 'incomplete' || page == 1,
      });
    });
    repository.close();
    repository.client.close();
    repository = ResumeRepository(
      catalogue,
      fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
      isCurrent: () => current,
    );
    await repository.refresh();
    expect(await repository.watch().first, hasLength(8));
    for (final invalid in ['duplicate', 'incomplete', 'forbidden']) {
      mode = invalid;
      await repository.refresh(force: true);
      expect(await repository.watch().first, hasLength(8));
    }
  });

  test(
    'an ebook in progress keeps another on-deck book by the same author',
    () async {
      adapter = FixtureAdapter((options) {
        final next = options.uri.path.endsWith('/ondeck');
        final data = next ? onDeckFixture() : fixture();
        final original =
            (data['content'] as List).first as Map<String, dynamic>;
        data['content'] = [
          {
            ...original,
            'id': next ? 'next-novel' : 'current-novel',
            'seriesId': 'same-author',
            'media': {
              ...original['media'] as Map<String, dynamic>,
              'mediaType': 'application/epub+zip',
              'mediaProfile': 'EPUB',
            },
            'readProgress': {'page': next ? 0 : 1, 'completed': false},
          },
        ];
        data['totalElements'] = 1;
        data['numberOfElements'] = 1;
        return jsonResponse(data);
      });
      repository.close();
      repository.client.close();
      repository = ResumeRepository(
        catalogue,
        fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
        isCurrent: () => current,
      );
      await repository.refresh();
      final entries = await repository.watch().first;
      expect(entries.map((entry) => entry.item.id).toSet(), {
        'current-novel',
        'next-novel',
      });
      expect(entries.where((entry) => entry.onDeck), hasLength(1));
    },
  );

  test('an in-progress book suppresses on-deck from the same series', () async {
    adapter = FixtureAdapter((options) {
      if (!options.uri.path.endsWith('/ondeck')) return jsonResponse(fixture());
      final data = onDeckFixture();
      (data['content'] as List).single['seriesId'] =
          (fixture()['content'] as List).first['seriesId'];
      return jsonResponse(data);
    });
    repository.close();
    repository.client.close();
    repository = ResumeRepository(
      catalogue,
      fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
      isCurrent: () => current,
    );
    await repository.refresh();
    final entries = await repository.watch().first;
    expect(entries, hasLength(6));
    expect(entries.any((entry) => entry.onDeck), false);
  });

  test(
    'older cached shelf payloads and missing series titles remain readable',
    () async {
      await repository.refresh();
      final row = await database.select(database.resumeSnapshots).getSingle();
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      payload.remove('onDeck');
      for (final book in payload['books'] as List) {
        (book as Map<String, dynamic>).remove('seriesTitle');
      }
      await database.customStatement(
        'UPDATE resume_snapshots SET payload=? WHERE account_id=?',
        [jsonEncode(payload), 'account'],
      );
      final entries = await repository.watch().first;
      expect(entries, hasLength(6));
      expect(entries.first.seriesTitle, 'Unknown series');
      expect(entries.any((entry) => entry.onDeck), false);
    },
  );

  test('pending local rewind wins, completion stays removed through acknowledgement', () async {
    final book = (fixture()['content'] as List).first;
    final id = book['id'] as String;
    final manifest = readerManifest(account: 'account', book: id);
    await catalogue.stage('g', [parseResumeEntry(book).item]);
    await catalogue.publish('g', DateTime.now(), () => true);
    await ReaderStore(database, 'account').saveManifest(manifest);
    final progress = ProgressStore(database, 'account');
    await repository.refresh();
    await progress.save(
      manifest,
      ReaderLocator(1, .5),
      operation: ProgressOperation.rewind,
    );
    expect((await repository.watch().first).first.pageIndex, 1);
    await repository.refresh(force: true);
    expect((await repository.watch().first).first.fraction, .5);
    await progress.save(
      manifest,
      ReaderLocator(1),
      operation: ProgressOperation.complete,
    );
    expect((await repository.watch().first).any((e) => e.item.id == id), false);
    for (final intent in await progress.pending()) {
      await progress.acknowledge(
        intent,
        ProgressSnapshot(
          revision: manifest.revision,
          pageIndex: 3,
          completed: true,
          version: 'acknowledged',
        ),
      );
    }
    expect((await repository.watch().first).any((e) => e.item.id == id), false);
  });

  test('pagination deduplicates, refuses incomplete publication and cancels late account results', () async {
    final full = fixture();
    var corrupt = false;
    adapter = FixtureAdapter((options) {
      if (options.uri.path.endsWith('/ondeck')) {
        return jsonResponse(emptyShelf());
      }
      final page = options.queryParameters['page'] as int;
      final all = full['content'] as List;
      return jsonResponse({
        ...full,
        'content': all.sublist(
          corrupt ? 0 : page * 3,
          corrupt ? 3 : (page + 1) * 3,
        ),
        'size': 3,
        'number': page,
        'totalPages': 2,
        'numberOfElements': 3,
        'last': page == 1,
      });
    });
    repository.close();
    repository.client.close();
    repository = ResumeRepository(
      catalogue,
      fixtureClient(savedSession.endpoint, savedSession.credentials, adapter),
      isCurrent: () => current,
    );
    await repository.refresh();
    expect(await repository.watch().first, hasLength(6));
    corrupt = true;
    await repository.refresh(force: true);
    expect(await repository.watch().first, hasLength(6));
    final response = Completer<ResponseBody>();
    repository.close();
    repository.client.close();
    repository = ResumeRepository(
      catalogue,
      fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((_) => response.future),
      ),
      isCurrent: () => current,
    );
    final request = repository.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    current = false;
    response.complete(
      jsonResponse({
        ...full,
        'content': <Object?>[],
        'numberOfElements': 0,
        'totalElements': 0,
        'totalPages': 0,
      }),
    );
    await request;
    expect(await repository.watch().first, hasLength(6));
  });

  test('changed server version updates cached locator while identical observation and pending intent preserve it', () async {
    final manifest = readerManifest(account: 'account');
    final progress = ProgressStore(database, 'account');
    final reader = ReaderStore(database, 'account');
    await progress.seedServerLocator(
      manifest,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 1,
        version: 'one',
      ),
    );
    await progress.seedServerLocator(
      manifest,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 2,
        version: 'two',
      ),
    );
    expect((await reader.locator(manifest)).pageIndex, 2);
    await progress.save(
      manifest,
      ReaderLocator(0, .2),
      operation: ProgressOperation.rewind,
    );
    await progress.seedServerLocator(
      manifest,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 3,
        version: 'three',
      ),
    );
    expect((await reader.locator(manifest)).pageIndex, 0);
    expect((await reader.locator(manifest)).fraction, .2);
  });
}
