import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/core/storage/app_database.dart' hide DownloadJob;
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/presentation/download_queue_card.dart';
import 'package:inkora/offline/presentation/download_status.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/catalogue_fakes.dart';
import '../support/reader_fakes.dart';

const _mib = 1024 * 1024;

ReaderManifest volume(String id, {String series = 'series-a'}) =>
    ReaderManifest(
      accountId: 'account',
      bookId: id,
      revision: 'r1',
      title: 'Volume $id',
      seriesId: series,
      pages: readerManifest().pages,
    );

Future<void> asset(
  AppDatabase database,
  String id, {
  required String book,
  required int bytes,
  String tier = 'download',
  String account = 'account',
  String revision = 'r1',
}) => database.customInsert(
  'INSERT INTO reader_assets (asset_id, tier, account_id, book_id, revision, page_index, representation, checksum, media_type, byte_length, last_access) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)',
  variables: [
    Variable(id),
    Variable(tier),
    Variable(account),
    Variable(book),
    Variable(revision),
    const Variable('original'),
    const Variable('checksum'),
    const Variable('image/png'),
    Variable(bytes),
    Variable(DateTime.utc(2026)),
  ],
  updates: {database.readerAssets},
);

void main() {
  late AppDatabase database;
  late DownloadStore store;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DownloadStore(database, 'account', Directory('/unused'));
  });
  tearDown(() => database.close());

  test(
    'storage summary aggregates downloads, reservations and cache',
    () async {
      final done = await store.enqueue(volume('a'));
      await store.state(done, DownloadState.complete);
      final pending = await store.enqueue(volume('b'));
      final reserved = (await store.job(pending))!.reservedBytes;
      await asset(database, 'a-0', book: 'a', bytes: 3 * _mib);
      await asset(database, 'c-0', book: 'c', bytes: _mib, tier: 'cache');
      final storage = await store.storage();
      expect(storage.downloaded, 3 * _mib);
      expect(storage.reserved, reserved);
      expect(storage.cached, _mib);
      expect(storage.quota, store.quota);
      // Same scope as the quota check.
      expect(storage.downloaded + storage.reserved, await store.occupied());
    },
  );

  test(
    'series groups carry committed bytes and catalogue volume numbers',
    () async {
      final catalogue = CatalogueStore(database, 'account');
      await catalogue.stage('g', [
        entry('series-a', kind: CatalogueKind.series, title: 'Alpha'),
        entry('a', title: 'Volume a', number: 2),
        entry('b', title: 'Volume b', number: 1),
      ]);
      await catalogue.publish('g', DateTime(2026), () => true);
      for (final id in ['a', 'b']) {
        await store.state(
          await store.enqueue(volume(id)),
          DownloadState.complete,
        );
      }
      await asset(database, 'a-0', book: 'a', bytes: 2 * _mib);
      await asset(database, 'a-1', book: 'a', bytes: _mib);
      await asset(database, 'b-0', book: 'b', bytes: _mib);
      // Another revision or account never counts.
      await asset(
        database,
        'a-old',
        book: 'a',
        bytes: 9 * _mib,
        revision: 'r0',
      );
      await asset(database, 'a-x', book: 'a', bytes: 9 * _mib, account: 'x');
      final group =
          (await store.completedSeries(includeReadingStatus: true).first)
              .single;
      expect(group.item.title, 'Alpha');
      expect([for (final b in group.books) b.item.id], ['b', 'a']);
      expect([for (final b in group.books) b.item.number], [1, 2]);
      expect([for (final b in group.books) b.bytes], [_mib, 3 * _mib]);
    },
  );

  test(
    'queue summary orders the current job first and counts the rest',
    () async {
      final running = await store.enqueue(volume('running'));
      final queued = await store.enqueue(volume('queued'));
      final paused = await store.enqueue(volume('paused'));
      final failed = await store.enqueue(volume('failed'));
      final done = await store.enqueue(volume('done'));
      await store.state(paused, DownloadState.paused);
      await store.state(failed, DownloadState.failed);
      await store.state(done, DownloadState.complete);
      await store.state(running, DownloadState.running);
      final summary = QueueSummary.of(await store.watch().first);
      expect(summary.current, running);
      expect(summary.ids, [running, queued, paused, failed]);
      expect((summary.queued, summary.paused, summary.failed), (1, 1, 1));
      // Without a transfer, the first queued job is current.
      await store.state(running, DownloadState.complete);
      final next = QueueSummary.of(await store.watch().first);
      expect(next.current, queued);
      expect(next, QueueSummary.of(await store.watch().first));
      expect(QueueSummary.of(const []).isEmpty, isTrue);
    },
  );

  test('status labels and sizes use the shared formats', () {
    final strings = AppStrings('en');
    expect(
      downloadStatusLabel(strings, DownloadState.running, ratio: .4),
      'Downloading · 40 %',
    );
    expect(downloadStatusLabel(strings, DownloadState.queued), 'Queued');
    expect(downloadStatusLabel(strings, DownloadState.paused), 'Paused');
    expect(
      downloadStatusLabel(strings, DownloadState.failed),
      'Download failed',
    );
    expect(
      downloadStatusLabel(strings, DownloadState.complete),
      'Ready offline',
    );
    expect(formatBytes(strings, 412 * _mib), '412 MiB');
    expect(formatBytes(strings, (1.4 * _mib).round()), '1.4 MiB');
    expect(formatBytes(strings, 1), '0.1 MiB');
    expect(formatBytes(strings, 0), '0 MiB');
    expect(formatBytes(strings, (1.24 * 1024 * _mib).round()), '1.2 GiB');
    expect(formatBytes(AppStrings('fr'), (1.4 * _mib).round()), '1,4 MiB');
  });

  test('storage summary is not recomputed for staged-page writes', () async {
    final jobs = StreamController<List<DownloadJob>>();
    addTearDown(jobs.close);
    final container = ProviderContainer(
      overrides: [
        downloadsProvider.overrideWith((ref) => jobs.stream),
        offlineCoordinatorProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    var runs = 0;
    container.listen(downloadStorageProvider, (previous, next) {
      if (next is AsyncData) runs++;
    }, fireImmediately: true);
    final id = await store.enqueue(volume('a'));
    Future<void> emit() async {
      jobs.add(await store.watch().first);
      await pumpEventQueue();
    }

    await emit();
    final baseline = runs;
    // A part write changes partCount only.
    await database.customInsert(
      'INSERT INTO download_parts (job_id, page_index, path, checksum, media_type, byte_length) VALUES (?, 0, ?, ?, ?, 1)',
      variables: [
        Variable(id),
        const Variable('/unused/part'),
        const Variable('c'),
        const Variable('image/png'),
      ],
    );
    await emit();
    expect(runs, baseline);
    await store.state(id, DownloadState.paused);
    await emit();
    expect(runs, baseline + 1);
  });
}
