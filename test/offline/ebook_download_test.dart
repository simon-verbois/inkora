import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

void main() {
  test('large PDF is streamed once, quota accounted, verified and restored as a file', () async {
    final root = await Directory.systemTemp.createTemp('inkora-ebook-');
    final db = AppDatabase(NativeDatabase(File('${root.path}/db')));
    final assets = ReaderAssetStore(
      db,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    final store = DownloadStore(
      db,
      'account',
      Directory('${root.path}/staging'),
    );
    final manifest = ReaderManifest(
      accountId: 'account',
      bookId: 'pdf',
      revision: 'r1',
      title: 'Large PDF',
      documentType: 'application/pdf',
      pages: [
        for (var i = 0; i < 40; i++)
          PageDimensions(1, 1, sizeBytes: i == 0 ? 40 * 1024 * 1024 : 0),
      ],
    );
    var transfers = 0;
    final scheduler = DownloadScheduler(
      store,
      assets,
      PageNetworkGate(),
      loadManifest: (_, _) async => manifest,
      isCurrent: () => true,
      transfer: (m, page, file, token, budget) async {
        transfers++;
        final handle = await file.open(mode: FileMode.write);
        await handle.writeString('%PDF-1.7\n');
        await handle.truncate(40 * 1024 * 1024);
        await handle.close();
        return (mediaType: 'application/pdf', byteLength: 40 * 1024 * 1024);
      },
    );
    addTearDown(() async {
      scheduler.close();
      await scheduler.idle;
      await assets.idle;
      await db.close();
      await root.delete(recursive: true);
    });
    final id = await scheduler.enqueue('pdf');
    await scheduler.idle;
    expect(
      (await store.job(id))!.state,
      DownloadState.complete,
      reason: (await store.job(id))!.error,
    );
    expect(transfers, 1);
    expect(await store.occupied(), 40 * 1024 * 1024);
    final file = await assets.documentFile(manifest);
    expect(await file!.length(), 40 * 1024 * 1024);
    expect(
      (await ReaderStore(db, 'account').manifest('pdf'))!.pages.length,
      40,
    );
    final other = ReaderManifest(
      accountId: 'other',
      bookId: 'pdf',
      revision: 'r1',
      title: 'Other',
      documentType: 'application/pdf',
      pages: [PageDimensions(1, 1)],
    );
    expect(await assets.documentFile(other), isNull);
    final handle = await file.open(mode: FileMode.append);
    await handle.setPosition(0);
    await handle.writeString('bad!');
    await handle.close();
    await expectLater(
      assets.documentFile(manifest),
      throwsA(isA<FormatException>()),
    );
  });
}
