import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/reader_fakes.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late ReaderAssetStore assets;
  late DownloadStore store;
  late DownloadScheduler scheduler;
  late PageNetworkGate gate;
  late ReaderManifest manifest;
  late DownloadTransfer transport;
  final requests = <int>[];
  Future<({String mediaType, int byteLength})> success(
    ReaderManifest manifest,
    int page,
    File file,
    CancelToken token,
    int budget,
  ) async {
    requests.add(page);
    await file.writeAsBytes(fixtureRaster, flush: true);
    return (mediaType: 'image/png', byteLength: fixtureRaster.length);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('inkora-download-test-');
    database = AppDatabase(NativeDatabase(File('${root.path}/state.sqlite')));
    assets = ReaderAssetStore(
      database,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    store = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/staging'),
    );
    gate = PageNetworkGate();
    manifest = readerManifest();
    requests.clear();
    transport = success;
    scheduler = DownloadScheduler(
      store,
      assets,
      gate,
      loadManifest: (_, _) async => manifest,
      transfer: (m, p, f, t, b) => transport(m, p, f, t, b),
      isCurrent: () => true,
    );
  });
  tearDown(() async {
    scheduler.close();
    await scheduler.idle;
    await assets.idle;
    await database.close();
    await root.delete(recursive: true);
  });

  test('duplicate jobs share identity, publish complete verified files, and remove explicitly', () async {
    final ids = await Future.wait([
      scheduler.enqueue('reader-book'),
      scheduler.enqueue('reader-book'),
    ]);
    await scheduler.idle;
    expect(ids[0], ids[1]);
    expect((await store.jobs()).length, 1);
    expect((await store.job(ids.first))!.state, DownloadState.complete);
    expect(requests, unorderedEquals([0, 1, 2, 3]));
    expect(await assets.isDownloaded(manifest), isTrue);
    expect(
      (await assets.read(
        manifest.key(3),
        'download',
        CancellationController(),
      ))!.bytes,
      fixtureRaster,
    );
    expect(await store.parts(ids.first), isEmpty);
    expect(await store.occupied(), fixtureRaster.length * 4);
    await scheduler.cancel(ids.first);
    expect(await assets.isDownloaded(manifest), isFalse);
    expect(await store.occupied(), 0);
  });
  test('global quota reservations are transactional across accounts and cover native/staging/promotion', () async {
    final quota = fixtureRaster.length * 4 * 3;
    store.quota = quota;
    await store.enqueue(manifest);
    final other = DownloadStore(
      database,
      'other',
      store.directory,
      quota: quota,
    );
    await expectLater(
      other.enqueue(readerManifest(account: 'other')),
      throwsA(isA<FileSystemException>()),
    );
    expect(await other.jobs(), isEmpty);
    expect(await store.occupied(), quota);
    await expectLater(
      store.configure(quota: quota - 1, wifiOnly: true),
      throwsA(isA<FileSystemException>()),
    );
  });
  test('disk failure never publishes an incomplete book and resume retains verified pages', () async {
    transport = (m, p, f, t, b) async {
      if (p == 1) throw const FileSystemException('No space left');
      return success(m, p, f, t, b);
    };
    final id = await scheduler.enqueue('reader-book');
    await scheduler.idle;
    expect((await store.job(id))!.state, DownloadState.failed);
    expect(await assets.isDownloaded(manifest), isFalse);
    expect((await store.parts(id)).keys, [0]);
    transport = success;
    await scheduler.resume(id);
    await scheduler.idle;
    expect(requests, unorderedEquals([0, 1, 2, 3]));
    expect(await assets.isDownloaded(manifest), isTrue);
  });
  test('pause cancels active streaming and releases admission; resume restarts the partial asset', () async {
    final started = Completer<void>();
    transport = (m, p, f, t, b) async {
      await f.writeAsString('partial');
      started.complete();
      await t.whenCancel;
      throw const ApiFailure(FailureKind.cancelled, 'Cancelled');
    };
    final id = await scheduler.enqueue('reader-book');
    await started.future;
    await scheduler.pause(id);
    expect((await store.job(id))!.state, DownloadState.paused);
    expect(gate.active, 0);
    expect(await store.file(id, 0, partial: true).exists(), isFalse);
    expect(await assets.isDownloaded(manifest), isFalse);
    transport = success;
    await scheduler.resume(id);
    await scheduler.idle;
    expect((await store.job(id))!.state, DownloadState.complete);
  });
  test(
    'cancel prevents late completion, removes staging and returns reservations',
    () async {
      final started = Completer<void>();
      transport = (m, p, f, t, b) async {
        started.complete();
        await t.whenCancel;
        return success(
          m,
          p,
          f,
          t,
          b,
        ); // Misbehaving transport returns after cancellation.
      };
      final id = await scheduler.enqueue('reader-book');
      await started.future;
      await scheduler.cancel(id);
      expect((await store.job(id))!.state, DownloadState.cancelled);
      expect(await store.occupied(), 0);
      expect(await assets.isDownloaded(manifest), isFalse);
      expect(await store.file(id, 0).parent.exists(), isFalse);
    },
  );
  test('restart recovers durable verified parts, rejects corrupt parts and discards partials/orphan promotions', () async {
    final id = await store.enqueue(manifest);
    for (var page = 0; page < 2; page++) {
      final file = store.file(id, page);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(fixtureRaster);
      await store.record(
        id,
        page,
        DownloadAsset(
          file,
          sha256.convert(fixtureRaster).toString(),
          'image/png',
          fixtureRaster.length,
        ),
      );
    }
    await store.file(id, 1).writeAsString('corrupt');
    await store.file(id, 2, partial: true).writeAsString('abandoned');
    await assets.downloadDirectory.create();
    await File('${assets.downloadDirectory.path}/orphan.part')
        .writeAsString('abandoned promotion');
    await store.state(id, DownloadState.verifying);
    scheduler.close();
    await scheduler.idle;
    await database.close();
    database = AppDatabase(NativeDatabase(File('${root.path}/state.sqlite')));
    store = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/staging'),
    );
    assets = ReaderAssetStore(
      database,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    await store.recover();
    await assets.recoverDownloads();
    expect((await store.parts(id)).keys, [0]);
    expect((await store.job(id))!.state, DownloadState.queued);
    expect(await store.file(id, 2, partial: true).exists(), isFalse);
    expect(await assets.downloadDirectory.list().toList(), isEmpty);
    // Force the other worker to finish page 2 before replacing corrupt page 1.
    // Recovery promises exact page coverage, not asynchronous transfer order.
    final nextPageWritten = Completer<void>();
    scheduler = DownloadScheduler(
      store,
      assets,
      gate,
      loadManifest: (_, _) async => manifest,
      transfer: (m, p, f, t, b) async {
        if (p == 1) await nextPageWritten.future;
        final result = await success(m, p, f, t, b);
        if (p == 2) nextPageWritten.complete();
        return result;
      },
      isCurrent: () => true,
    );
    scheduler.kick();
    await scheduler.idle;
    expect(requests, unorderedEquals([1, 2, 3]));
    expect(await assets.verifyDownloadedManifest(manifest), isTrue);
    expect(await assets.isDownloaded(manifest), isTrue);
  });
  test(
    'changed revisions and incorrect lengths never combine or publish bytes',
    () async {
      final id = await store.enqueue(manifest);
      manifest = readerManifest(revision: 'changed');
      scheduler.kick();
      await scheduler.idle;
      expect((await store.job(id))!.state, DownloadState.failed);
      expect(requests, isEmpty);
      expect(await database.select(database.readerDownloads).get(), isEmpty);
      manifest = readerManifest();
      transport = (m, p, f, t, b) async {
        await f.writeAsBytes(fixtureRaster.sublist(0, 8));
        return (mediaType: 'image/png', byteLength: 8);
      };
      await scheduler.resume(id);
      await scheduler.idle;
      expect((await store.job(id))!.state, DownloadState.failed);
      expect(await database.select(database.readerDownloads).get(), isEmpty);
    },
  );
  test(
    'queued foreground takes the next available slot ahead of download demand',
    () async {
      final active = PageRequest(priority: PagePriority.download);
      await gate.acquire(CancellationController(), active);
      final waitingDownload = PageRequest(priority: PagePriority.download);
      final queued = gate.acquire(CancellationController(), waitingDownload);
      final visible = PageRequest();
      await gate.acquire(CancellationController(), visible);
      expect(gate.active, 2);
      gate.release(active);
      gate.release(visible);
      await queued;
      gate.release(waitingDownload);
      expect(gate.active, 0);
    },
  );
  test('foreground preempts a saturated single-slot download without losing durable work', () async {
    gate = PageNetworkGate(limit: 1);
    // A single page exercises the ordinary lease, regardless of worker/file I/O order.
    manifest = readerManifest(count: 1);
    scheduler.close();
    final started = Completer<void>();
    transport = (m, p, f, t, b) async {
      started.complete();
      await t.whenCancel;
      throw const ApiFailure(FailureKind.cancelled, 'Preempted');
    };
    scheduler = DownloadScheduler(
      store,
      assets,
      gate,
      loadManifest: (_, _) async => manifest,
      transfer: (m, p, f, t, b) => transport(m, p, f, t, b),
      isCurrent: () => true,
    );
    final id = await scheduler.enqueue('reader-book');
    await started.future;
    final foreground = PageRequest();
    await gate.acquire(CancellationController(), foreground);
    expect(gate.active, 1);
    // Foreground admission proves preemption already happened. Stop the automatic
    // retry before inspecting durable state, including on a heavily loaded host.
    await scheduler.suspend(true);
    gate.release(foreground);
    await scheduler.idle;
    final job = (await store.job(id))!;
    expect(job.state, DownloadState.queued, reason: '${job.error}');
    expect(job.attempt, 0);
    expect(
      job.retryAt - DateTime.now().millisecondsSinceEpoch,
      lessThanOrEqualTo(250),
    );
    expect(await assets.isDownloaded(manifest), isFalse);
  });
  test('verified publication does not serialize foreground cache writes behind book copying', () async {
    final source = await File('${root.path}/source.png')
        .writeAsBytes(fixtureRaster);
    final asset = DownloadAsset(
      source,
      sha256.convert(fixtureRaster).toString(),
      'image/png',
      fixtureRaster.length,
    );
    final order = <String>[];
    final publication = assets
        .installVerifiedDownload(manifest, {
          for (var page = 0; page < manifest.pages.length; page++) page: asset,
        }, CancellationController())
        .then((_) => order.add('download'));
    final cache = assets
        .cache(
          EncodedPage(
            key: manifest.key(0),
            bytes: fixtureRaster,
            mediaType: 'image/png',
          ),
        )
        .then((_) => order.add('cache'));
    await Future.wait([publication, cache]);
    expect(order.first, 'cache');
    expect(await assets.verifyDownloadedManifest(manifest), isTrue);
  });

  test(
    'pages transfer two at a time per job and a failure keeps its root cause',
    () async {
      var active = 0, peak = 0;
      transport = (m, p, f, t, b) async {
        active++;
        peak = active > peak ? active : peak;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return success(m, p, f, t, b);
      };
      final id = await scheduler.enqueue('reader-book');
      await scheduler.idle;
      expect(peak, downloadPageConcurrency);
      expect((await store.job(id))!.state, DownloadState.complete);
      expect(requests.toSet(), {0, 1, 2, 3});

      await scheduler.cancel(id);
      requests.clear();
      transport = (m, p, f, t, b) async {
        if (p == 1) {
          throw const ApiFailure(FailureKind.notFound, 'Page missing.');
        }
        // The sibling transfer observes the induced cancellation.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (t.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled, 'Cancelled.');
        }
        return success(m, p, f, t, b);
      };
      final retry = await scheduler.enqueue('reader-book');
      await scheduler.idle;
      final failed = (await store.job(retry))!;
      expect(failed.state, DownloadState.failed);
      expect(failed.error, 'Page missing.');
    },
  );

  test('reader demand reclaims only the borrowed download stream; the job continues', () async {
    var loads = 0;
    scheduler.close();
    final bothActive = Completer<void>();
    final release = Completer<void>();
    var active = 0;
    transport = (m, p, f, t, b) async {
      active++;
      if (active == 2 && !bothActive.isCompleted) bothActive.complete();
      try {
        await Future.any([release.future, t.whenCancel]);
        if (t.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled, 'Preempted');
        }
        return await success(m, p, f, t, b);
      } finally {
        active--;
      }
    };
    scheduler = DownloadScheduler(
      store,
      assets,
      gate,
      loadManifest: (_, _) async {
        loads++;
        return manifest;
      },
      transfer: (m, p, f, t, b) => transport(m, p, f, t, b),
      isCurrent: () => true,
    );
    final id = await scheduler.enqueue('reader-book');
    await bothActive.future;
    final reader = PageRequest();
    await gate.acquire(CancellationController(), reader);
    gate.release(reader);
    release.complete();
    await scheduler.idle;
    final job = (await store.job(id))!;
    expect(job.state, DownloadState.complete);
    expect(job.attempt, 0);
    // Enqueue, run start and final revision check: no restart after preemption.
    expect(loads, 3);
    expect(await assets.isDownloaded(manifest), isTrue);
  });
}
