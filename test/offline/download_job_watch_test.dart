import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart' hide DownloadJob;
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';

import '../support/reader_fakes.dart';

void main() {
  test('job watch carries part counts, skips unchanged emissions and exposes identity columns without decoding manifests', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DownloadStore(
      database,
      'reader-account',
      Directory('/unused'),
    );
    final id = await store.enqueue(readerManifest());
    final emissions = <List<DownloadJob>>[];
    final subscription = store.watch().listen(emissions.add);
    addTearDown(subscription.cancel);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));
    await settle();
    expect(emissions, hasLength(1));
    final job = emissions.single.single;
    expect(job.bookId, 'reader-book');
    expect(job.accountId, 'reader-account');
    expect(job.partCount, 0);

    await store.record(
      id,
      0,
      DownloadAsset(store.file(id, 0), 'a' * 64, 'image/png', 10),
    );
    await settle();
    expect(emissions.last.single.partCount, 1);

    final count = emissions.length;
    // Rewriting the same state wakes the query but must not reach widgets.
    await store.state(id, DownloadState.queued);
    await settle();
    expect(emissions, hasLength(count));

    expect(await store.stateOf(id), DownloadState.queued);
    expect(await store.nextQueuedAt(), 0);
    await store.state(id, DownloadState.paused);
    expect(await store.nextQueuedAt(), isNull);
    expect(emissions.last.single.manifest.pages, hasLength(4));
  });
}
