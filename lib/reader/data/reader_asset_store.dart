import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/errors/failure_kind.dart';
import '../../core/storage/app_database.dart';
import '../domain/content_key.dart';
import 'manifest_codec.dart';
import '../domain/page_source.dart';
import '../domain/reader_manifest.dart';

const maximumEncodedPageBytes = 32 * 1024 * 1024;
const maximumDocumentBytes = 512 * 1024 * 1024;
const _inlineHashBytes = 256 * 1024;
const _touchInterval = Duration(minutes: 1);

Future<String> rasterChecksum(Uint8List bytes) async {
  if (bytes.length < _inlineHashBytes) return sha256.convert(bytes).toString();
  return Isolate.run(() => sha256.convert(bytes).toString());
}

void validateRaster(Uint8List bytes, String mediaType) {
  if (bytes.isEmpty || bytes.length > maximumEncodedPageBytes) {
    throw const ReaderFailure(
      FailureKind.corruptContent,
      'Image exceeds the encoded page budget.',
    );
  }
  bool starts(List<int> prefix) =>
      bytes.length >= prefix.length &&
      List.generate(
        prefix.length,
        (i) => bytes[i] == prefix[i],
      ).every((v) => v);
  final valid = switch (mediaType) {
    'image/png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
    'image/jpeg' => starts([255, 216, 255]),
    'image/gif' => starts([71, 73, 70, 56]),
    'image/webp' =>
      starts([82, 73, 70, 70]) &&
          bytes.length >= 12 &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP',
    _ => false,
  };
  if (!valid) {
    throw const ReaderFailure(
      FailureKind.corruptContent,
      'Invalid or unsupported page image.',
    );
  }
}

final class DownloadAsset {
  const DownloadAsset(
    this.file,
    this.checksum,
    this.mediaType,
    this.byteLength,
  );
  final File file;
  final String checksum;
  final String mediaType;
  final int byteLength;
}

/// Hash file streams off the UI isolate; inspections retain at most one chunk.
Future<DownloadAsset> inspectDownloadAsset(
  File file,
  String mediaType, {
  int maximumBytes = maximumEncodedPageBytes,
}) async {
  final path = file.path;
  final document =
      mediaType == 'application/epub+zip' || mediaType == 'application/pdf';
  final hardLimit = document ? maximumDocumentBytes : maximumEncodedPageBytes;
  final result = await Isolate.run(() async {
    final source = File(path);
    final length = await source.length();
    if (length < 1 || length > maximumBytes || length > hardLimit) {
      throw const FileSystemException('Invalid download length');
    }
    final handle = await source.open();
    try {
      final header = await handle.read(12);
      if (document) {
        final prefix = mediaType == 'application/pdf'
            ? [37, 80, 68, 70, 45]
            : [80, 75, 3, 4];
        if (header.length < prefix.length ||
            !List.generate(
              prefix.length,
              (i) => header[i] == prefix[i],
            ).every((v) => v)) {
          throw const FormatException('Invalid document signature');
        }
      } else {
        validateRaster(header, mediaType);
      }
    } finally {
      await handle.close();
    }
    var count = 0;
    final digest = await sha256
        .bind(
          source.openRead().map((chunk) {
            count += chunk.length;
            if (count > maximumBytes || count > hardLimit) {
              throw const FileSystemException(
                'Download exceeds byte reservation',
              );
            }
            return chunk;
          }),
        )
        .first;
    if (count != length) {
      throw const FileSystemException('Download changed during verification');
    }
    return (count, digest.toString());
  });
  return DownloadAsset(file, result.$2, mediaType, result.$1);
}

/// Immutable hashed file names prevent traversal and bind bytes to full identity.
final class ReaderAssetStore {
  ReaderAssetStore(
    this.database,
    this.cacheDirectory,
    this.downloadDirectory, {
    this.cacheQuota = 512 * 1024 * 1024,
  }) {
    if (cacheQuota < 0) throw ArgumentError('Invalid cache quota');
  }
  final AppDatabase database;
  final Directory cacheDirectory;
  final Directory downloadDirectory;
  final int cacheQuota;
  Future<void> _tail = Future.value();
  Future<void> get idle => _tail;
  bool _needsEviction = false;
  bool _needsSweep = false;
  final _touched = <String, DateTime>{};
  final _pins = <String, int>{};
  final _promotions = <String>{};

  String assetId(ContentKey key) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            key.accountId,
            key.bookId,
            key.revision,
            key.pageIndex,
            key.representation,
          ]),
        ),
      )
      .toString();
  File _file(String tier, String id, String checksum) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Invalid local asset index.',
      );
    }
    return File(
      '${(tier == 'download' ? downloadDirectory : cacheDirectory).path}/$id-$checksum',
    );
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Uint8List> _boundedRead(
    File file, {
    int maximumBytes = maximumEncodedPageBytes,
  }) async {
    final size = await file.length();
    if (size < 1 || size > maximumEncodedPageBytes) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Invalid local image length.',
      );
    }
    if (size > maximumBytes) {
      throw const ReaderFailure(
        FailureKind.cancelled,
        'Speculative page exceeds its reserved bytes.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (builder.length + chunk.length > maximumBytes) {
        throw const ReaderFailure(
          FailureKind.corruptContent,
          'Local image exceeds its byte budget.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Reads and verifies a local page against its index. Pages above the
  /// inline threshold are bounded, read and hashed inside one worker isolate;
  /// Isolate.exit transfers the verified buffer back without another copy.
  Future<Uint8List> _verifiedRead(
    File file, {
    required int maximumBytes,
    required int expectedLength,
    required String checksum,
  }) async {
    const integrity = ReaderFailure(
      FailureKind.corruptContent,
      'Saved page failed integrity verification.',
    );
    if (expectedLength < _inlineHashBytes) {
      final bytes = await _boundedRead(file, maximumBytes: maximumBytes);
      if (bytes.length != expectedLength ||
          sha256.convert(bytes).toString() != checksum) {
        throw integrity;
      }
      return bytes;
    }
    final size = await file.length();
    if (size < 1 || size > maximumEncodedPageBytes) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Invalid local image length.',
      );
    }
    if (size > maximumBytes) {
      throw const ReaderFailure(
        FailureKind.cancelled,
        'Speculative page exceeds its reserved bytes.',
      );
    }
    if (size != expectedLength) throw integrity;
    final path = file.path;
    final verified = await Isolate.run(() async {
      final builder = BytesBuilder(copy: false);
      // Read one byte past the indexed length so growth is still detected.
      await for (final chunk in File(path).openRead(0, expectedLength + 1)) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length != expectedLength ||
          sha256.convert(bytes).toString() != checksum) {
        return null;
      }
      return bytes;
    });
    if (verified == null) throw integrity;
    return verified;
  }

  /// Cache LRU bookkeeping is coarse: one write per asset per interval keeps
  /// eviction order meaningful without a SQLite write on every page view.
  Future<void> _touch(String id) async {
    final now = DateTime.now().toUtc();
    final previous = _touched[id];
    if (previous != null && now.difference(previous) < _touchInterval) return;
    if (_touched.length >= 4096) _touched.clear();
    _touched[id] = now;
    try {
      await database.customStatement(
        "UPDATE reader_assets SET last_access = ? WHERE asset_id = ? AND tier = 'cache'",
        [now.toIso8601String(), id],
      );
    } catch (_) {
      /* LRU bookkeeping cannot gate verified local bytes. */
    }
  }

  /// Optional local-only evidence. Check size before read() so a small analysis
  /// budget never invalidates a valid larger cache entry as a corrupt asset.
  Future<EncodedPage?> readForPairing(
    ContentKey key,
    CancellationSignal cancellation, {
    required int maximumBytes,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT tier FROM reader_assets WHERE asset_id = ? AND byte_length <= ? ORDER BY tier DESC',
          variables: [Variable(assetId(key)), Variable(maximumBytes)],
        )
        .get();
    for (final row in rows) {
      final page = await read(
        key,
        row.read<String>('tier'),
        cancellation,
        maximumBytes: maximumBytes,
      );
      if (page != null) return page;
    }
    return null;
  }

  Future<EncodedPage?> read(
    ContentKey key,
    String tier,
    CancellationSignal cancellation, {
    int maximumBytes = maximumEncodedPageBytes,
  }) async {
    if (cancellation.isCancelled) {
      throw const ReaderFailure(
        FailureKind.cancelled,
        'Page loading cancelled.',
      );
    }
    if (tier == 'download') {
      final rows = await database
          .customSelect(
            'SELECT 1 FROM reader_downloads WHERE account_id = ? AND book_id = ? AND revision = ?',
            variables: [
              Variable(key.accountId),
              Variable(key.bookId),
              Variable(key.revision),
            ],
          )
          .get();
      if (rows.isEmpty) return null;
    }
    final id = assetId(key);
    final pin = '$tier:$id';
    _pins[pin] = (_pins[pin] ?? 0) + 1;
    try {
      final rows = await database
          .customSelect(
            'SELECT checksum, byte_length, media_type FROM reader_assets WHERE asset_id = ? AND tier = ?',
            variables: [Variable(id), Variable(tier)],
          )
          .get();
      if (rows.isEmpty) return null;
      final row = rows.single;
      final checksum = row.read<String>('checksum');
      final bytes = await _verifiedRead(
        _file(tier, id, checksum),
        maximumBytes: maximumBytes,
        expectedLength: row.read<int>('byte_length'),
        checksum: checksum,
      );
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Page loading cancelled.',
        );
      }
      final type = row.read<String>('media_type');
      validateRaster(bytes, type);
      if (tier == 'cache') await _touch(id);
      return EncodedPage(key: key, bytes: bytes, mediaType: type);
    } on FileSystemException {
      if (tier == 'cache') await invalidateCache(key);
      return null;
    } on ReaderFailure catch (error) {
      if (error.kind == FailureKind.cancelled) rethrow;
      if (tier == 'cache') await invalidateCache(key);
      rethrow;
    } finally {
      final count = (_pins[pin] ?? 1) - 1;
      if (count == 0) {
        _pins.remove(pin);
      } else {
        _pins[pin] = count;
      }
      if (_needsEviction || _needsSweep) {
        unawaited(_serial(_evict).catchError((Object _) {}));
      }
    }
  }

  Future<void> _removeIndex(String id, String tier) => database.customStatement(
    'DELETE FROM reader_assets WHERE asset_id = ? AND tier = ?',
    [id, tier],
  );

  Future<void> _writeFile(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _index(
    ContentKey key,
    String tier,
    String checksum,
    String mediaType,
    int length,
  ) => database.customStatement(
    'INSERT OR REPLACE INTO reader_assets (asset_id, tier, account_id, book_id, revision, page_index, representation, checksum, media_type, byte_length, last_access) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      assetId(key),
      tier,
      key.accountId,
      key.bookId,
      key.revision,
      key.pageIndex,
      key.representation,
      checksum,
      mediaType,
      length,
      DateTime.now().toUtc().toIso8601String(),
    ],
  );

  Future<void> cache(EncodedPage page) => _serial(() async {
    validateRaster(page.bytes, page.mediaType);
    if (page.bytes.length > cacheQuota) return;
    final id = assetId(page.key);
    final checksum = await rasterChecksum(page.bytes);
    await _writeFile(_file('cache', id, checksum), page.bytes);
    await _index(
      page.key,
      'cache',
      checksum,
      page.mediaType,
      page.bytes.length,
    );
    _touched[id] = DateTime.now().toUtc();
    await _evictOverQuota();
  });

  /// Hot-path quota enforcement: one aggregate query, and LRU rows are only
  /// mapped when the cache actually exceeds its quota.
  Future<void> _evictOverQuota() async {
    final usage = await database
        .customSelect(
          "SELECT COALESCE(SUM(byte_length), 0) AS total FROM reader_assets WHERE tier = 'cache'",
        )
        .getSingle();
    var total = usage.read<int>('total');
    if (total <= cacheQuota) {
      _needsEviction = false;
      return;
    }
    final rows = await database
        .customSelect(
          "SELECT asset_id, checksum, byte_length FROM reader_assets WHERE tier = 'cache' ORDER BY last_access ASC, asset_id ASC",
        )
        .get();
    for (final row in rows) {
      if (total <= cacheQuota) break;
      final id = row.read<String>('asset_id');
      if (_pins.containsKey('cache:$id')) continue;
      final file = _file('cache', id, row.read<String>('checksum'));
      if (await file.exists()) await file.delete();
      await _removeIndex(id, 'cache');
      _touched.remove(id);
      total -= row.read<int>('byte_length');
    }
    _needsEviction = total > cacheQuota;
  }

  /// Full recovery: quota plus a sweep of unindexed/orphaned cache files.
  Future<void> _evict() async {
    await _evictOverQuota();
    _needsSweep = false;
    final remaining = await database
        .customSelect(
          "SELECT asset_id, checksum FROM reader_assets WHERE tier = 'cache'",
        )
        .get();
    final referenced = remaining
        .map(
          (r) => '${r.read<String>('asset_id')}-${r.read<String>('checksum')}',
        )
        .toSet();
    if (await cacheDirectory.exists()) {
      await for (final entity in cacheDirectory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!referenced.contains(name)) {
          if (_pins.containsKey('cache:${name.split('-').first}')) {
            _needsSweep = true;
            continue;
          }
          await entity.delete();
        }
      }
    }
  }

  Future<void> recoverCache() => _serial(_evict);

  Future<void> invalidateCache(ContentKey key) => _serial(() async {
    final id = assetId(key);
    final rows = await database
        .customSelect(
          "SELECT checksum FROM reader_assets WHERE asset_id = ? AND tier = 'cache'",
          variables: [Variable(id)],
        )
        .get();
    await _removeIndex(id, 'cache');
    _touched.remove(id);
    if (_pins.containsKey('cache:$id')) {
      // The active reader still holds the file; its release sweeps it.
      _needsSweep = true;
      return;
    }
    for (final row in rows) {
      final file = _file('cache', id, row.read<String>('checksum'));
      if (await file.exists()) await file.delete();
    }
  });

  /// Returns a verified original file without materializing it in Dart memory.
  Future<File?> documentFile(ReaderManifest manifest) async {
    if (!manifest.isDocument || !await isDownloaded(manifest)) return null;
    final id = assetId(manifest.key(0));
    final row = await database
        .customSelect(
          "SELECT checksum, byte_length, media_type FROM reader_assets WHERE asset_id = ? AND tier = 'download'",
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final file = _file('download', id, row.read<String>('checksum'));
    final asset = await inspectDownloadAsset(
      file,
      row.read<String>('media_type'),
      maximumBytes: manifest.maximumAssetBytes,
    );
    if (asset.checksum != row.read<String>('checksum') ||
        asset.byteLength != row.read<int>('byte_length')) {
      throw const FormatException('Document integrity verification failed');
    }
    return file;
  }

  Future<bool> isDownloaded(ReaderManifest manifest) async =>
      (await database
              .customSelect(
                'SELECT 1 FROM reader_downloads WHERE account_id = ? AND book_id = ? AND revision = ?',
                variables: [
                  Variable(manifest.accountId),
                  Variable(manifest.bookId),
                  Variable(manifest.revision),
                ],
              )
              .get())
          .isNotEmpty;

  Future<bool> verifyDownloadedManifest(ReaderManifest manifest) async {
    if (!await isDownloaded(manifest)) return false;
    for (var page = 0; page < manifest.assetCount; page++) {
      final key = manifest.key(page);
      final rows = await database
          .customSelect(
            "SELECT checksum, media_type, byte_length FROM reader_assets WHERE tier = 'download' AND asset_id = ?",
            variables: [Variable(assetId(key))],
          )
          .get();
      if (rows.isEmpty) return false;
      final row = rows.single;
      try {
        final inspected = await inspectDownloadAsset(
          _file('download', assetId(key), row.read<String>('checksum')),
          row.read<String>('media_type'),
          maximumBytes: manifest.maximumAssetBytes,
        );
        if (inspected.checksum != row.read<String>('checksum') ||
            inspected.byteLength != row.read<int>('byte_length')) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> removeDownload(ReaderManifest manifest) => _serial(() async {
    final rows = await database
        .customSelect(
          "SELECT asset_id, checksum FROM reader_assets WHERE tier = 'download' AND account_id = ? AND book_id = ? AND revision = ?",
          variables: [
            Variable(manifest.accountId),
            Variable(manifest.bookId),
            Variable(manifest.revision),
          ],
        )
        .get();
    await database.transaction(() async {
      await database.customStatement(
        'DELETE FROM reader_downloads WHERE account_id = ? AND book_id = ? AND revision = ?',
        [manifest.accountId, manifest.bookId, manifest.revision],
      );
      await database.customStatement(
        "DELETE FROM reader_assets WHERE tier = 'download' AND account_id = ? AND book_id = ? AND revision = ?",
        [manifest.accountId, manifest.bookId, manifest.revision],
      );
    });
    for (final row in rows) {
      final file = _file(
        'download',
        row.read<String>('asset_id'),
        row.read<String>('checksum'),
      );
      if (await file.exists()) await file.delete();
    }
  });

  /// Run before starting any publisher; abandoned promotions never remain pinned.
  Future<void> recoverDownloads() => _serial(() async {
    final rows = await database
        .customSelect(
          "SELECT asset_id, checksum FROM reader_assets WHERE tier = 'download'",
        )
        .get();
    final referenced = rows
        .map(
          (r) => '${r.read<String>('asset_id')}-${r.read<String>('checksum')}',
        )
        .toSet();
    if (await downloadDirectory.exists()) {
      await for (final entity in downloadDirectory.list(followLinks: false)) {
        if (entity is File &&
            !_promotions.contains(entity.path) &&
            !referenced.contains(entity.uri.pathSegments.last)) {
          await entity.delete();
        }
      }
    }
  });

  /// Publish a completed download through this verified boundary.
  /// Incomplete/mismatched imports never make a book available as downloaded.
  Future<void> installVerifiedDownload(
    ReaderManifest manifest,
    Map<int, DownloadAsset> assets,
    CancellationSignal cancellation,
  ) async {
    if (assets.length != manifest.assetCount ||
        [for (var i = 0; i < manifest.assetCount; i++) i]
            .any((i) => !assets.containsKey(i))) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Download manifest is incomplete.',
      );
    }
    void check() {
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Download verification cancelled.',
        );
      }
    }

    final promoted = <String>{};
    try {
      for (var page = 0; page < manifest.assetCount; page++) {
        check();
        final asset = assets[page]!;
        final inspected = await inspectDownloadAsset(
          asset.file,
          asset.mediaType,
          maximumBytes: manifest.maximumAssetBytes,
        );
        if (inspected.byteLength != asset.byteLength ||
            inspected.checksum != asset.checksum) {
          throw const ReaderFailure(
            FailureKind.corruptContent,
            'Download checksum does not match.',
          );
        }
        final key = manifest.key(page);
        final finalFile = _file('download', assetId(key), asset.checksum);
        final partial = File('${finalFile.path}.part');
        promoted.add(finalFile.path);
        promoted.add(partial.path);
        _promotions.add(finalFile.path);
        _promotions.add(partial.path);
        await finalFile.parent.create(recursive: true);
        try {
          check();
          await asset.file.copy(partial.path);
          final copied = await inspectDownloadAsset(
            partial,
            asset.mediaType,
            maximumBytes: manifest.maximumAssetBytes,
          );
          if (copied.byteLength != asset.byteLength ||
              copied.checksum != asset.checksum) {
            throw const ReaderFailure(
              FailureKind.corruptContent,
              'Copied download failed verification.',
            );
          }
          final handle = await partial.open(mode: FileMode.append);
          try {
            await handle.flush();
          } finally {
            await handle.close();
          }
          check();
          await partial.rename(finalFile.path);
        } finally {
          if (await partial.exists()) await partial.delete();
        }
      }
      check();
      final payload = manifest.isDocument
          ? await encodeReaderManifest(manifest)
          : jsonEncode(manifest.toJson());
      // File inspection/copying never holds the cache-write serialization tail.
      // Only the short publication transaction excludes index mutations.
      await _serial(
        () => database.transaction(() async {
          check();
          final accessed = DateTime.now().toUtc();
          await database.batch((batch) {
            batch.insertAllOnConflictUpdate(database.readerAssets, [
              for (var page = 0; page < manifest.assetCount; page++)
                ReaderAssetsCompanion.insert(
                  assetId: assetId(manifest.key(page)),
                  tier: 'download',
                  accountId: manifest.accountId,
                  bookId: manifest.bookId,
                  revision: manifest.revision,
                  pageIndex: page,
                  representation: manifest.key(page).representation,
                  checksum: assets[page]!.checksum,
                  mediaType: assets[page]!.mediaType,
                  byteLength: assets[page]!.byteLength,
                  lastAccess: accessed,
                ),
            ]);
            batch.insertAllOnConflictUpdate(database.readerDownloads, [
              ReaderDownloadsCompanion.insert(
                accountId: manifest.accountId,
                bookId: manifest.bookId,
                revision: manifest.revision,
              ),
            ]);
            if (manifest.documentType != 'application/epub+zip' ||
                manifest.positions.isNotEmpty) {
              batch.insertAllOnConflictUpdate(database.readerManifests, [
                ReaderManifestsCompanion.insert(
                  accountId: manifest.accountId,
                  bookId: manifest.bookId,
                  payload: payload,
                ),
              ]);
            }
          });
          check();
        }),
      );
    } finally {
      _promotions.removeAll(promoted);
    }
  }
}
