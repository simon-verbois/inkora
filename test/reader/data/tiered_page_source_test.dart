import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/reader_fakes.dart';

void main() {
  late Directory folder;
  late AppDatabase database;
  late ReaderAssetStore assets;
  late FixturePageSource remote;
  late ReaderManifest manifest;
  late TieredPageSource source;
  final cancelledFailure = isA<ReaderFailure>().having(
    (e) => e.kind,
    'kind',
    FailureKind.cancelled,
  );
  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 30));
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('inkora-pages-');
    database = AppDatabase(NativeDatabase.memory());
    assets = ReaderAssetStore(
      database,
      Directory('${folder.path}/cache'),
      Directory('${folder.path}/download'),
    );
    remote = FixturePageSource();
    manifest = readerManifest();
    source = TieredPageSource(manifest, assets, remote, PageNetworkGate());
  });
  tearDown(() async {
    source.close();
    await flush();
    await database.close();
    await folder.delete(recursive: true);
  });
  Future<EncodedPage> read(int page, [CancellationController? signal]) =>
      source.read(
        manifest.key(page),
        cancellation: signal ?? CancellationController(),
      );
  Future<void> downloaded() async {
    final file = await File('${folder.path}/import.png')
        .writeAsBytes(fixtureRaster);
    await assets.installVerifiedDownload(manifest, {
      for (var i = 0; i < manifest.pages.length; i++)
        i: DownloadAsset(
          file,
          sha256.convert(fixtureRaster).toString(),
          'image/png',
          fixtureRaster.length,
        ),
    }, CancellationController());
  }

  test(
    'remote pages become integrity-checked cache hits with no more networking',
    () async {
      expect((await read(0)).key, manifest.key(0));
      remote.offline = true;
      expect((await read(0)).bytes, fixtureRaster);
      expect(remote.requests, [manifest.key(0)]);
      expect(() => manifest.key(4), throwsRangeError);
      expect(
        () => source.read(
          readerManifest(account: 'other').key(0),
          cancellation: CancellationController(),
        ),
        throwsA(isA<ReaderFailure>()),
      );
    },
  );
  test(
    'complete verified download takes precedence over cache and remote',
    () async {
      await downloaded();
      await assets.cache(
        EncodedPage(
          key: manifest.key(0),
          bytes: fixtureRaster,
          mediaType: 'image/png',
        ),
      );
      remote.offline = true;
      expect((await read(0)).bytes, fixtureRaster);
      expect(remote.requests, isEmpty);
      final downloads = await assets.downloadDirectory.list().toList();
      await (downloads.first as File).writeAsString('corrupt');
      for (var i = 0; i < 4; i++) {
        final key = manifest.key(i);
        if ((downloads.first as File).path.contains(assets.assetId(key))) {
          if (i == 0) {
            expect((await read(i)).bytes, fixtureRaster);
          } else {
            await expectLater(
              read(i),
              throwsA(
                isA<ReaderFailure>().having(
                  (e) => e.kind,
                  'kind',
                  FailureKind.corruptContent,
                ),
              ),
            );
          }
        }
      }
    },
  );
  test(
    'incomplete and checksum-mismatched imports never publish downloads',
    () async {
      final file = await File('${folder.path}/import.png')
          .writeAsBytes(fixtureRaster);
      await expectLater(
        assets.installVerifiedDownload(manifest, {
          0: DownloadAsset(file, '0' * 64, 'image/png', fixtureRaster.length),
        }, CancellationController()),
        throwsA(isA<ReaderFailure>()),
      );
      await expectLater(
        assets.installVerifiedDownload(manifest, {
          for (var i = 0; i < 4; i++)
            i: DownloadAsset(file, '0' * 64, 'image/png', fixtureRaster.length),
        }, CancellationController()),
        throwsA(isA<ReaderFailure>()),
      );
      expect(await database.select(database.readerDownloads).get(), isEmpty);
    },
  );
  test('cache corruption is rejected instead of advertised as offline availability', () async {
    await read(0);
    final file = (await assets.cacheDirectory.list().toList()).single as File;
    await file.writeAsString('invalid');
    remote.offline = true;
    await expectLater(
      read(0),
      throwsA(
        isA<ReaderFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.corruptContent,
        ),
      ),
    );
    expect(await database.select(database.readerAssets).get(), isEmpty);
  });
  test(
    'missing downloaded file repairs from remote without crossing revisions',
    () async {
      await downloaded();
      for (final file in await assets.downloadDirectory.list().toList()) {
        await file.delete();
      }
      expect((await read(0)).bytes, fixtureRaster);
      expect(remote.requests, [manifest.key(0)]);
      final other = readerManifest(revision: 'new-revision');
      expect(
        await assets.read(other.key(0), 'download', CancellationController()),
        isNull,
      );
      expect(
        await assets.read(
          readerManifest(account: 'another').key(0),
          'cache',
          CancellationController(),
        ),
        isNull,
      );
    },
  );
  test(
    'cache byte quota evicts files and orphan recovery preserves downloads',
    () async {
      assets = ReaderAssetStore(
        database,
        Directory('${folder.path}/cache'),
        Directory('${folder.path}/download'),
        cacheQuota: fixtureRaster.length,
      );
      await assets.cache(
        EncodedPage(
          key: manifest.key(0),
          bytes: fixtureRaster,
          mediaType: 'image/png',
        ),
      );
      await assets.cache(
        EncodedPage(
          key: manifest.key(1),
          bytes: fixtureRaster,
          mediaType: 'image/png',
        ),
      );
      expect((await assets.cacheDirectory.list().toList()).length, 1);
      await File('${assets.cacheDirectory.path}/orphan.part')
          .writeAsString('partial');
      await downloaded();
      await assets.recoverCache();
      expect((await assets.cacheDirectory.list().toList()).length, 1);
      expect((await assets.downloadDirectory.list().toList()).length, 4);
    },
  );
  test('foreground promotes a queued speculative flight and retains it across prefetch cancellation', () async {
    remote.hold = true;
    final held = source.readAhead(
      manifest.key(0),
      cancellation: CancellationController(),
      request: PageRequest(priority: PagePriority.lookahead),
    );
    await flush();
    final speculative = CancellationController();
    final queued = source.readAhead(
      manifest.key(1),
      cancellation: speculative,
      request: PageRequest(priority: PagePriority.lookahead),
    );
    final checked = expectLater(queued, throwsA(cancelledFailure));
    await flush();
    expect(remote.requests, [manifest.key(0)]);
    final visible = read(1);
    await flush();
    expect(remote.requests, [manifest.key(0), manifest.key(1)]);
    speculative.cancel();
    await checked;
    expect(remote.cancelled, isEmpty);
    remote.complete(manifest.key(1));
    expect((await visible).key, manifest.key(1));
    remote.complete(manifest.key(0));
    await held;
    expect(source.gate.active, 0);
  });

  test('underestimated speculation cannot impose its smaller byte cap on foreground', () async {
    remote.hold = true;
    final speculative = source.readAhead(
      manifest.key(0),
      cancellation: CancellationController(),
      request: PageRequest(
        priority: PagePriority.lookahead,
        maximumBytes: fixtureRaster.length - 1,
      ),
    );
    final rejected = expectLater(speculative, throwsA(isA<ReaderFailure>()));
    await flush();
    final visible = read(0);
    remote.complete(manifest.key(0));
    await rejected;
    await flush();
    expect(remote.requests.length, 2);
    remote.complete(manifest.key(0));
    expect((await visible).bytes, fixtureRaster);
  });

  test('one subscriber cancelling never aborts another subscriber', () async {
    remote.hold = true;
    final first = CancellationController();
    final second = CancellationController();
    final a = read(0, first);
    final aCheck = expectLater(a, throwsA(cancelledFailure));
    final b = read(0, second);
    await flush();
    first.cancel();
    await aCheck;
    expect(remote.cancelled, isEmpty);
    remote.complete(manifest.key(0));
    expect((await b).bytes, fixtureRaster);
    expect(remote.requests.length, 1);
  });
  test('last subscriber cancellation aborts transfer and immediate retry gets a fresh flight', () async {
    remote.hold = true;
    final cancellation = CancellationController();
    final page = read(0, cancellation);
    final check = expectLater(page, throwsA(cancelledFailure));
    await flush();
    cancellation.cancel();
    await check;
    await flush();
    expect(remote.cancelled, [manifest.key(0)]);
    remote.hold = false;
    expect((await read(0)).bytes, fixtureRaster);
    expect(remote.requests.length, 2);
  });
  test('queued cancellation is removed before admission and does not consume a network slot', () async {
    remote.hold = true;
    source.close();
    final gate = PageNetworkGate(limit: 1);
    source = TieredPageSource(manifest, assets, remote, gate);
    final a = read(0);
    final signal = CancellationController();
    final b = read(1, signal);
    final check = expectLater(b, throwsA(cancelledFailure));
    await flush();
    signal.cancel();
    await check;
    remote.complete(manifest.key(0));
    await a;
    await flush();
    expect(remote.requests, [manifest.key(0)]);
    expect(gate.active, 0);
  });
  test(
    'close cancels active and queued requests without late cache writes',
    () async {
      remote.hold = true;
      final a = read(0);
      final b = read(1);
      final aCheck = expectLater(a, throwsA(cancelledFailure));
      final bCheck = expectLater(b, throwsA(cancelledFailure));
      await flush();
      source.close();
      await Future.wait([aCheck, bCheck]);
      expect(await database.select(database.readerAssets).get(), isEmpty);
    },
  );
}
