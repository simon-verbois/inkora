import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';

import '../../support/catalogue_fakes.dart';
import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';

void main() {
  late AppDatabase database;
  late Directory folder;
  late ReaderRepository repository;
  late CatalogueStore catalogue;
  final manifest = readerManifest();
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    folder = await Directory.systemTemp.createTemp('inkora-handoff-');
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((_) => throw StateError('No implicit remote metadata')),
    );
    repository = ReaderRepository(
      ReaderStore(database, manifest.accountId),
      ReaderAssetStore(
        database,
        Directory('${folder.path}/cache'),
        Directory('${folder.path}/downloads'),
      ),
      client,
      PageNetworkGate(),
      isCurrent: () => true,
    );
    catalogue = CatalogueStore(database, manifest.accountId);
    addTearDown(client.close);
  });
  tearDown(() async {
    repository.close();
    await repository.assets.idle;
    await database.close();
    await folder.delete(recursive: true);
  });
  test('series sequence uses metadata order and never jumps inaccessible or removed books', () async {
    await catalogue.stage('a', [
      entry(manifest.bookId, seriesId: manifest.seriesId, number: 2),
      entry('unrelated', seriesId: 'another', number: 3),
      entry('id-z', seriesId: manifest.seriesId, number: 1),
      entry('id-a', seriesId: manifest.seriesId, number: 3),
    ]);
    await catalogue.publish('a', DateTime.utc(2026), () => true);
    expect(await repository.nextChapterId(manifest), 'id-a');
    await catalogue.stage('b', [
      entry(manifest.bookId, seriesId: manifest.seriesId, number: 2),
      entry('id-a', seriesId: manifest.seriesId, number: 3, available: false),
      entry('id-b', seriesId: manifest.seriesId, number: 4),
    ]);
    await catalogue.publish('b', DateTime.utc(2026), () => true);
    expect(await repository.nextChapterId(manifest), isNull);
    expect(
      await repository.nextChapterId(readerManifest(account: 'other')),
      isNull,
    );
  });
  test('explicit reading-list order overrides series numbers and retains permissions', () async {
    await catalogue.stage('a', [
      entry(manifest.bookId, number: 9),
      entry('next', number: 1),
      entry(
        'list',
        kind: CatalogueKind.readlist,
        members: [manifest.bookId, 'next'],
      ),
    ]);
    await catalogue.publish('a', DateTime.utc(2026), () => true);
    expect(
      await repository.nextChapterId(
        manifest,
        order: const CatalogueQuery(
          kind: CatalogueKind.book,
          groupKind: CatalogueKind.readlist,
          groupId: 'list',
          sort: CatalogueSort.sequence,
        ),
      ),
      'next',
    );
  });
  test('chapter handoff reuses encoded buffers and source leases; revision refresh cancels old ownership', () async {
    await repository.store.saveManifest(manifest);
    final first = await repository.open(manifest.bookId);
    final second = await repository.open(manifest.bookId);
    expect(identical(first.source, second.source), true);
    repository.memory.put(
      EncodedPage(
        key: manifest.key(0),
        bytes: fixtureRaster,
        mediaType: 'image/png',
      ),
    );
    repository.release(first);
    expect(
      (await second.source.read(
        manifest.key(0),
        cancellation: CancellationController(),
      )).bytes,
      fixtureRaster,
    );
    repository.release(second);
    final next = await repository.open(manifest.bookId);
    expect(repository.memory.contains(manifest.key(0)), true);
    final revised = readerManifest(revision: 'revision-b');
    await repository.store.saveManifest(revised);
    final fresh = await repository.open(manifest.bookId);
    expect(repository.memory.contains(manifest.key(0)), false);
    await expectLater(
      next.source.read(manifest.key(0), cancellation: CancellationController()),
      throwsA(isA<Exception>()),
    );
    repository.release(next);
    repository.release(fresh);
  });
}
