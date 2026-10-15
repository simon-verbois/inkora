import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/reader/data/komga_reader_remote.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../test/support/connection_fakes.dart';
import '../test/support/reader_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native resumable download and atomic outbox survive database restart through Komga adapters',
    (tester) async {
      const account = 'native-offline-fixture';
      final support = await getApplicationSupportDirectory();
      final root = await Directory('${support.path}/native-offline-fixture')
          .create(recursive: true);
      var database = await openAppDatabase();
      final book = <String, dynamic>{
        'id': 'native-book',
        'libraryId': 'library',
        'seriesId': 'series',
        'fileHash': 'fixture-content',
        'fileLastModified': '2026-10-11T12:00:00Z',
        'sizeBytes': fixtureRaster.length,
        'metadata': {'title': 'Native offline fixture'},
        'media': {'status': 'READY', 'mediaProfile': 'DIVINA', 'pagesCount': 1},
        'readProgress': null,
      };
      final adapter = FixtureAdapter((request) {
        if (request.path.endsWith('/pages')) {
          return jsonResponse([
            {
              'number': 1,
              'mediaType': 'image/png',
              'width': 1,
              'height': 1,
              'sizeBytes': fixtureRaster.length,
            },
          ]);
        }
        if (request.path.endsWith('/pages/1')) {
          return ResponseBody.fromBytes(
            fixtureRaster,
            200,
            headers: {
              'content-type': ['image/png'],
              'content-length': ['${fixtureRaster.length}'],
            },
          );
        }
        if (request.method == 'PATCH') {
          book['readProgress'] = {
            ...request.data as Map<String, dynamic>,
            'lastModified': '2026-10-11T12:01:00Z',
          };
          return ResponseBody.fromString('', 204);
        }
        return jsonResponse(book);
      });
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final manifest = await KomgaReaderRemote.loadManifest(
        client,
        account,
        'native-book',
        CancelToken(),
      );
      var assets = ReaderAssetStore(
        database,
        Directory('${root.path}/cache'),
        Directory('${root.path}/downloads'),
      );
      var store = DownloadStore(
        database,
        account,
        Directory('${root.path}/staging'),
      );
      var scheduler = DownloadScheduler.komga(
        store,
        assets,
        PageNetworkGate(),
        client,
        () => true,
      );
      try {
        final id = await store.enqueue(manifest);
        await store.state(id, DownloadState.running);
        final partial = store.file(id, 0, partial: true);
        await partial.parent.create(recursive: true);
        await partial.writeAsString('partial');
        await ProgressStore(
          database,
          account,
        ).save(manifest, ReaderLocator(0, .4));
        scheduler.close();
        await database.close();
        database = await openAppDatabase();
        store = DownloadStore(
          database,
          account,
          Directory('${root.path}/staging'),
        );
        assets = ReaderAssetStore(
          database,
          Directory('${root.path}/cache'),
          Directory('${root.path}/downloads'),
        );
        scheduler = DownloadScheduler.komga(
          store,
          assets,
          PageNetworkGate(),
          client,
          () => true,
        );
        await scheduler.recover();
        expect((await store.job(id))!.state, DownloadState.queued);
        expect(await partial.exists(), isFalse);
        scheduler.kick();
        await scheduler.idle;
        expect((await store.job(id))!.state, DownloadState.complete);
        expect(
          (await assets.read(
            manifest.key(0),
            'download',
            CancellationController(),
          ))!.bytes,
          fixtureRaster,
        );
        final progress = ProgressStore(database, account);
        await progress.recover();
        expect((await progress.pending()).single.pageIndex, 0);
        expect(
          (await ReaderStore(database, account).locator(manifest)).fraction,
          .4,
        );
        final sync = ProgressSync(
          progress,
          KomgaProgressRemote(client, account),
          PageNetworkGate(),
          isCurrent: () => true,
        );
        await sync.replay();
        sync.close();
        expect(await progress.pending(), isEmpty);
        expect((book['readProgress'] as Map)['page'], 1);
        expect((book['readProgress'] as Map)['completed'], true);
        expect(adapter.requests.where((r) => r.method == 'PATCH').length, 1);
        // Published downloads stay valid even if the final job-state update crashed.
        await store.state(id, DownloadState.verifying);
        await scheduler.recover();
        expect((await store.job(id))!.state, DownloadState.complete);
      } finally {
        scheduler.close();
        await scheduler.idle;
        await assets.idle;
        client.close();
        final jobs = await store.jobs();
        for (final job in jobs) {
          await assets.removeDownload(job.manifest);
          await store.clean(job.id);
        }
        await (database.delete(
          database.downloadJobs,
        )..where((row) => row.accountId.equals(account))).go();
        for (final table in [
          'reader_manifests',
          'reader_positions',
          'progress_heads',
          'progress_events',
          'offline_settings',
        ]) {
          await database.customStatement(
            'DELETE FROM $table WHERE account_id = ?',
            [account],
          );
        }
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
}
