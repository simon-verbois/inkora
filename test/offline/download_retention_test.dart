import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/download_retention_store.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/reader_fakes.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late DownloadStore downloads;
  late DownloadRetentionStore retention;
  late ProgressStore progress;
  final start = DateTime.utc(2030);
  Future<void> complete(ReaderManifest manifest) async {
    final id = await downloads.enqueue(manifest);
    await downloads.state(id, DownloadState.complete);
    await progress.observe(
      manifest.bookId,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 3,
        completed: true,
      ),
    );
    await retention.readingStateChanged(manifest.bookId, now: start);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('inkora-retention-');
    database = AppDatabase(NativeDatabase(File('${root.path}/test.sqlite')));
    downloads = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/staging'),
    );
    retention = DownloadRetentionStore(database, 'reader-account');
    progress = ProgressStore(database, 'reader-account');
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'opt-in survives reopen, respects 24 hours and account boundaries',
    () async {
      final manifest = readerManifest();
      await complete(manifest);
      expect(await retention.enabled('series'), isFalse);
      expect(
        await retention.due(now: start.add(const Duration(days: 2))),
        isEmpty,
      );
      await retention.configure('series', true);
      expect(
        await DownloadRetentionStore(database, 'other').enabled('series'),
        isFalse,
      );
      expect(
        await retention.due(
          now: start.add(const Duration(hours: 23, minutes: 59)),
        ),
        isEmpty,
      );
      expect(
        (await retention.due(now: start.add(const Duration(hours: 24))))
            .single
            .bookId,
        manifest.bookId,
      );
      expect(
        await retention.due(
          now: start.add(const Duration(days: 2)),
          jobId: 'missing',
        ),
        isEmpty,
      );
      await database.close();
      database = AppDatabase(NativeDatabase(File('${root.path}/test.sqlite')));
      retention = DownloadRetentionStore(database, 'reader-account');
      expect(await retention.enabled('series'), isTrue);
      expect(
        (await retention.due(now: start.add(const Duration(days: 2)))).length,
        1,
      );
      expect(
        await DownloadRetentionStore(
          database,
          'other',
        ).due(now: start.add(const Duration(days: 2))),
        isEmpty,
      );
      await retention.configure('series', false);
      expect(
        await retention.due(now: start.add(const Duration(days: 2))),
        isEmpty,
      );
    },
  );

  test('rewind cancels the deadline and a new completion starts a new grace period', () async {
    final manifest = readerManifest();
    await complete(manifest);
    await retention.configure('series', true);
    await progress.observe(
      manifest.bookId,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 1,
        completed: false,
      ),
    );
    expect(
      await retention.due(now: start.add(const Duration(days: 2))),
      isEmpty,
    );
    await progress.observe(
      manifest.bookId,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 3,
        completed: true,
      ),
    );
    await retention.readingStateChanged(
      manifest.bookId,
      now: start.add(const Duration(days: 2)),
    );
    expect(
      await retention.due(now: start.add(const Duration(days: 2, hours: 23))),
      isEmpty,
    );
    expect(
      (await retention.due(now: start.add(const Duration(days: 3)))).length,
      1,
    );
    final changes =
        (await database.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n');
    await progress.observe(
      manifest.bookId,
      ProgressSnapshot(
        revision: manifest.revision,
        pageIndex: 3,
        completed: true,
      ),
    );
    await retention.configure('series', true);
    await retention.due(now: start.add(const Duration(days: 3)));
    expect(
      (await database.customSelect('SELECT total_changes() AS n').getSingle())
          .read<int>('n'),
      changes,
      reason: 'unchanged progress/policy and due checks write nothing',
    );
  });

  test(
    'all completed revisions participate; unfinished and other series never do',
    () async {
      await complete(readerManifest());
      await complete(readerManifest(revision: 'revision-b'));
      await downloads.enqueue(readerManifest(book: 'queued'));
      await retention.configure('series', true);
      expect(
        (await retention.due(now: start.add(const Duration(days: 2)))).length,
        2,
      );
      await retention.configure('series', false);
      await retention.configure('other-series', true);
      expect(
        await retention.due(now: start.add(const Duration(days: 2))),
        isEmpty,
      );
    },
  );

  test(
    'legacy/server-only completion starts its delay when first observed',
    () async {
      final manifest = readerManifest();
      final id = await downloads.enqueue(manifest);
      await downloads.state(id, DownloadState.complete);
      await database.customStatement(
        'INSERT INTO progress_heads(account_id,book_id,sequence,baseline) VALUES (?,?,0,?)',
        [
          manifest.accountId,
          manifest.bookId,
          ProgressSnapshot(
            revision: manifest.revision,
            completed: true,
          ).encode(),
        ],
      );
      await retention.configure('series', true);
      expect(await retention.due(now: start), isEmpty);
      expect(
        await retention.due(now: start.add(const Duration(hours: 23))),
        isEmpty,
      );
      expect(
        (await retention.due(now: start.add(const Duration(days: 1)))).length,
        1,
      );
    },
  );
}
