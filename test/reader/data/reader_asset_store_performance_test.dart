import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../../support/reader_fakes.dart';

/// PNG signature followed by filler: passes magic validation, and exceeds the
/// inline hashing threshold so verification runs in the worker isolate.
Uint8List largeRaster(int length, {int fill = 7}) {
  final bytes = Uint8List(length)..fillRange(0, length, fill);
  bytes.setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
  return bytes;
}

void main() {
  late Directory folder;
  late AppDatabase database;
  final manifest = readerManifest();

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('inkora-asset-perf-');
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await database.close();
    await folder.delete(recursive: true);
  });

  ReaderAssetStore store({int quota = 512 * 1024 * 1024}) => ReaderAssetStore(
    database,
    Directory('${folder.path}/cache'),
    Directory('${folder.path}/download'),
    cacheQuota: quota,
  );

  Future<List<File>> cacheFiles(ReaderAssetStore assets) async => [
    if (await assets.cacheDirectory.exists())
      await for (final entity in assets.cacheDirectory.list())
        if (entity is File) entity,
  ];

  test('large cached pages verify in a worker isolate and detect same-length corruption', () async {
    final assets = store();
    final bytes = largeRaster(400 * 1024);
    final key = manifest.key(0);
    await assets.cache(
      EncodedPage(key: key, bytes: bytes, mediaType: 'image/png'),
    );
    final read = await assets.read(key, 'cache', CancellationController());
    expect(read!.bytes, bytes);

    final file = (await cacheFiles(assets)).single;
    final corrupted = Uint8List.fromList(bytes)..[bytes.length - 1] = 9;
    await file.writeAsBytes(corrupted, flush: true);
    await expectLater(
      assets.read(key, 'cache', CancellationController()),
      throwsA(
        isA<ReaderFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.corruptContent,
        ),
      ),
    );
    await assets.idle;
    // The corrupt entry is unindexed and its file removed without a sweep.
    expect(await cacheFiles(assets), isEmpty);
    expect(await assets.read(key, 'cache', CancellationController()), isNull);
  });

  test('speculative byte budgets still cancel oversized large reads', () async {
    final assets = store();
    final key = manifest.key(0);
    await assets.cache(
      EncodedPage(
        key: key,
        bytes: largeRaster(300 * 1024),
        mediaType: 'image/png',
      ),
    );
    await expectLater(
      assets.read(
        key,
        'cache',
        CancellationController(),
        maximumBytes: 100 * 1024,
      ),
      throwsA(
        isA<ReaderFailure>().having(
          (e) => e.kind,
          'kind',
          FailureKind.cancelled,
        ),
      ),
    );
  });

  test(
    'quota eviction removes least recently used pages and their files',
    () async {
      final assets = store(quota: 2 * 300 * 1024);
      for (var page = 0; page < 3; page++) {
        await assets.cache(
          EncodedPage(
            key: manifest.key(page),
            bytes: largeRaster(300 * 1024, fill: page + 1),
            mediaType: 'image/png',
          ),
        );
      }
      expect(await cacheFiles(assets), hasLength(2));
      expect(
        await assets.read(manifest.key(0), 'cache', CancellationController()),
        isNull,
      );
      expect(
        await assets.read(manifest.key(2), 'cache', CancellationController()),
        isNotNull,
      );
    },
  );

  test('cache reads throttle LRU index writes', () async {
    final assets = store();
    final key = manifest.key(0);
    await assets.cache(
      EncodedPage(key: key, bytes: fixtureRaster, mediaType: 'image/png'),
    );
    Future<String> lastAccess() async =>
        (await database
                .customSelect(
                  "SELECT last_access FROM reader_assets WHERE tier = 'cache'",
                )
                .getSingle())
            .read<String>('last_access');
    await database.customStatement(
      "UPDATE reader_assets SET last_access = '2000-01-01T00:00:00.000Z'",
    );
    // The write itself counts as a touch: a read within the interval is free.
    await assets.read(key, 'cache', CancellationController());
    expect(await lastAccess(), '2000-01-01T00:00:00.000Z');
  });

  test(
    'invalidation deletes the cache file without a directory sweep',
    () async {
      final assets = store();
      final key = manifest.key(0);
      await assets.cache(
        EncodedPage(key: key, bytes: fixtureRaster, mediaType: 'image/png'),
      );
      expect(await cacheFiles(assets), hasLength(1));
      await assets.invalidateCache(key);
      expect(await cacheFiles(assets), isEmpty);
      final rows = await database
          .customSelect('SELECT COUNT(*) AS n FROM reader_assets')
          .getSingle();
      expect(rows.read<int>('n'), 0);
    },
  );
}
