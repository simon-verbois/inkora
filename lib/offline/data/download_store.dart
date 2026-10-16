import '../../features/library/domain/catalogue_filters.dart';

import 'dart:convert';
import 'dart:io';

import '../../reader/data/reader_store.dart';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../../reader/data/reader_asset_store.dart';
import '../../reader/domain/reader_manifest.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/domain/catalogue_metadata.dart';

const defaultDownloadQuota = 2 * 1024 * 1024 * 1024;

typedef DownloadedBook = ({DownloadJob job, CatalogueItem item});
typedef DownloadedSeries = ({
  CatalogueItem item,
  CatalogueItem artwork,
  List<DownloadedBook> books,
});

enum DownloadState {
  queued,
  running,
  verifying,
  complete,
  paused,
  cancelled,
  failed,
}

/// Job rows expose indexed identity columns directly. The manifest JSON (one
/// entry per page) is decoded lazily, so job lists, polling and watches only
/// pay for it when a caller actually needs page data.
final class DownloadJob {
  DownloadJob(QueryRow row)
    : _title = row.readNullable<String>('display_title'),
      _assetCount = row.readNullable<int>('asset_count'),
      id = row.read<String>('id'),
      accountId = row.read<String>('account_id'),
      bookId = row.read<String>('book_id'),
      revision = row.read<String>('revision'),
      _manifestJson = row.read<String>('manifest'),
      state = DownloadState.values.byName(row.read<String>('state')),
      reservedBytes = row.read<int>('reserved_bytes'),
      attempt = row.read<int>('attempt'),
      retryAt = row.read<int>('retry_at'),
      error = row.readNullable<String>('error'),
      partCount = row.data.containsKey('part_count')
          ? row.read<int>('part_count')
          : null;
  final String? _title;
  final int? _assetCount;
  String get title => _title ?? manifest.title;
  int get assetCount => _assetCount ?? manifest.assetCount;
  final String id, accountId, bookId, revision;
  final String _manifestJson;
  late final ReaderManifest manifest = ReaderManifest.fromJson(
    jsonDecode(_manifestJson) as Map<String, dynamic>,
  );
  final DownloadState state;
  final int reservedBytes, attempt, retryAt;
  final String? error;

  /// Staged page count; only present on [DownloadStore.watch] rows.
  final int? partCount;

  @override
  bool operator ==(Object other) =>
      other is DownloadJob &&
      other.id == id &&
      other.accountId == accountId &&
      other.revision == revision &&
      other.state == state &&
      other.reservedBytes == reservedBytes &&
      other.attempt == attempt &&
      other.retryAt == retryAt &&
      other.error == error &&
      other.partCount == partCount;

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    revision,
    state,
    reservedBytes,
    attempt,
    retryAt,
    error,
    partCount,
  );
}

final class DownloadStore {
  DownloadStore(
    this.database,
    this.accountId,
    this.directory, {
    this.quota = defaultDownloadQuota,
  });
  final AppDatabase database;
  final String accountId;
  final Directory directory;
  int quota;
  bool wifiOnly = true;
  Future<void> loadSettings() async {
    final rows = await database
        .customSelect(
          'SELECT quota, wifi_only FROM offline_settings WHERE account_id = ?',
          variables: [Variable(accountId)],
        )
        .get();
    if (rows.isNotEmpty) {
      quota = rows.single.read<int>('quota');
      wifiOnly = rows.single.read<bool>('wifi_only');
    }
  }

  Future<void> configure({required int quota, required bool wifiOnly}) async {
    if (quota < await occupied()) {
      throw const FileSystemException(
        'Quota is below reserved and downloaded bytes',
      );
    }
    await database.customStatement(
      'INSERT OR REPLACE INTO offline_settings (account_id, quota, wifi_only) VALUES (?, ?, ?)',
      [accountId, quota, wifiOnly],
    );
    this.quota = quota;
    this.wifiOnly = wifiOnly;
  }

  String id(ReaderManifest manifest) => sha256
      .convert(
        utf8.encode(
          jsonEncode([manifest.accountId, manifest.bookId, manifest.revision]),
        ),
      )
      .toString();
  int pageBudget(ReaderManifest manifest, int page) =>
      manifest.pages[page].sizeBytes > 0
      ? manifest.pages[page].sizeBytes
      : maximumEncodedPageBytes;
  File file(String jobId, int page, {bool partial = false}) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(jobId) || page < 0) {
      throw ArgumentError('Invalid staging identity');
    }
    return File(
      '${directory.path}/$jobId/$page${partial ? '.part' : '.ready'}',
    );
  }

  Future<int> occupied() async {
    final committed = await database
        .customSelect(
          "SELECT COALESCE(SUM(byte_length), 0) AS n FROM reader_assets WHERE tier = 'download'",
        )
        .getSingle();
    final reserved = await database
        .customSelect(
          "SELECT COALESCE(SUM(reserved_bytes), 0) AS n FROM download_jobs WHERE state NOT IN ('complete', 'cancelled')",
        )
        .getSingle();
    return committed.read<int>('n') + reserved.read<int>('n');
  }

  Future<String> enqueue(ReaderManifest manifest) =>
      database.transaction(() async {
        if (manifest.accountId != accountId) {
          throw ArgumentError('Mismatched download account');
        }
        final jobId = id(manifest);
        final existing = await job(jobId);
        if (existing != null && existing.state != DownloadState.cancelled) {
          return jobId;
        }
        var reservation = 0;
        for (var i = 0; i < manifest.assetCount; i++) {
          final budget = pageBudget(manifest, i);
          if (budget > manifest.maximumAssetBytes) {
            throw const FileSystemException('Page exceeds download budget');
          }
          // Native staging, Dart staging and final promotion have separate reservations.
          reservation += budget * 3;
        }
        if (await occupied() + reservation > quota) {
          throw const FileSystemException('Download quota exceeded');
        }
        if (manifest.isDocument) {
          await ReaderStore(database, accountId).saveManifest(manifest);
        }
        await database.customInsert(
          'INSERT OR REPLACE INTO download_jobs (id, account_id, book_id, revision, manifest, state, reserved_bytes) VALUES (?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable(jobId),
            Variable(accountId),
            Variable(manifest.bookId),
            Variable(manifest.revision),
            Variable(jsonEncode(manifest.toJson(includePositions: false))),
            const Variable('queued'),
            Variable(reservation),
          ],
          updates: {database.downloadJobs},
        );
        return jobId;
      });
  Future<DownloadJob?> job(String jobId) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM download_jobs WHERE id = ? AND account_id = ?',
          variables: [Variable(jobId), Variable(accountId)],
        )
        .get();
    return rows.isEmpty ? null : DownloadJob(rows.single);
  }

  Stream<List<DownloadJob>> watch() => database
      .customSelect(
        "SELECT j.*, json_extract(j.manifest, '\$.title') AS display_title, CASE WHEN json_extract(j.manifest, '\$.documentType') IS NOT NULL THEN 1 ELSE json_array_length(j.manifest, '\$.pages') END AS asset_count, (SELECT COUNT(*) FROM download_parts p WHERE p.job_id = j.id) AS part_count FROM download_jobs j WHERE j.account_id = ? ORDER BY j.rowid",
        variables: [Variable(accountId)],
        readsFrom: {database.downloadJobs, database.downloadParts},
      )
      .watch()
      .map((rows) => rows.map(DownloadJob.new).toList())
      .distinct(_sameJobs);

  static bool _sameJobs(List<DownloadJob> a, List<DownloadJob> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// One published, account-scoped snapshot; covers reuse catalogue cache keys.
  /// Saved manifests still identify books removed from the remote catalogue.
  Stream<List<DownloadedBook>> completedBooks() => database
      .customSelect(
        '''SELECT j.*, e.modified AS cover_modified, e.descriptive_metadata AS book_metadata
        FROM download_jobs j
        LEFT JOIN catalogue_snapshots s ON s.account_id=j.account_id
        LEFT JOIN catalogue_entries e ON e.account_id=j.account_id
          AND e.generation=s.generation AND e.kind='book' AND e.remote_id=j.book_id
        WHERE j.account_id=? AND j.state='complete' ORDER BY j.rowid''',
        variables: [Variable(accountId)],
        readsFrom: {database.downloadJobs, database.catalogueSnapshots},
      )
      .watch()
      .map((rows) => [for (final row in rows) _downloadedBook(row)]);

  DownloadedBook _downloadedBook(QueryRow row) {
    final job = DownloadJob(row);
    final manifest = job.manifest;
    final fields = jsonDecode(
      row.readNullable<String>('book_metadata') ?? '{}',
    ) as Map<String, dynamic>;
    final parent = jsonDecode(
      row.readNullable<String>('series_metadata') ?? '{}',
    ) as Map<String, dynamic>;
    // Match the catalogue's effective facet values when book fields are absent.
    for (final facet in CatalogueFacet.values) {
      final value = fields[facet.name];
      if (value == null || value == '' || value is List && value.isEmpty) {
        fields[facet.name] = parent[facet.name];
      }
    }
    final item = CatalogueItem(
      kind: CatalogueKind.book,
      id: manifest.bookId,
      title: manifest.title,
      metadata: CatalogueMetadata.fromJson({
        ...fields,
        'mediaType': manifest.documentType ?? '',
      }),
      libraryId: manifest.libraryId,
      seriesId: manifest.seriesId,
      pageCount: manifest.pages.length,
      modified:
          row.readNullable<int>('cover_modified') ?? manifest.revision.hashCode,
    );
    return (job: job, item: item);
  }

  /// Group completed volumes using only the account's published generation.
  /// Manifests retain access when series metadata has disappeared.
  Stream<List<DownloadedSeries>> completedSeries() => database
      .customSelect(
        '''SELECT j.*, b.modified AS cover_modified,
      COALESCE(b.series_id, json_extract(j.manifest, '\$.seriesId')) AS parent_id,
      b.number AS book_number, b.descriptive_metadata AS book_metadata, p.descriptive_metadata AS series_metadata, p.title AS series_title,
      p.modified AS series_modified, p.library_id AS series_library
    FROM download_jobs j
    LEFT JOIN catalogue_snapshots s ON s.account_id=j.account_id
    LEFT JOIN catalogue_entries b ON b.account_id=j.account_id
      AND b.generation=s.generation AND b.kind='book' AND b.remote_id=j.book_id
    LEFT JOIN catalogue_entries p ON p.account_id=j.account_id
      AND p.generation=s.generation AND p.kind='series'
      AND p.remote_id=COALESCE(b.series_id, json_extract(j.manifest, '\$.seriesId'))
    WHERE j.account_id=? AND j.state='complete'
    ORDER BY COALESCE(b.number, 0), j.rowid''',
        variables: [Variable(accountId)],
        readsFrom: {database.downloadJobs, database.catalogueSnapshots},
      )
      .watch()
      .map((rows) {
        final groups = <String, List<DownloadedBook>>{};
        final metadata = <String, QueryRow>{};
        for (final row in rows) {
          final book = _downloadedBook(row);
          final parent = row.readNullable<String>('parent_id');
          final key = book.item.isEbook
              ? book.item.identity
              : 'series:${parent ?? 'unassigned'}';
          groups.putIfAbsent(key, () => []).add(book);
          metadata[key] = row;
        }
        return [
          for (final group in groups.entries)
            _downloadedSeries(metadata[group.key]!, group.value),
        ];
      });

  DownloadedSeries _downloadedSeries(
    QueryRow first,
    List<DownloadedBook> saved,
  ) {
    final id = first.readNullable<String>('parent_id');
    // Several revisions of one book must not create several volume cards.
    final books = <String, DownloadedBook>{};
    for (final book in saved) {
      books[book.item.id] = book;
    }
    if (saved.first.item.isEbook) {
      return (
        item: saved.last.item,
        artwork: saved.last.item,
        books: List.unmodifiable(books.values),
      );
    }
    final title = first.readNullable<String>('series_title');
    final item = CatalogueItem(
      kind: CatalogueKind.series,
      id: id ?? 'unassigned',
      title: title ?? (id == null ? 'Unassigned series' : 'Saved series'),
      libraryId: first.readNullable<String>('series_library'),
      metadata: CatalogueMetadata.fromJson(
        jsonDecode(first.readNullable<String>('series_metadata') ?? '{}')
            as Map<String, dynamic>,
      ),
      itemCount: books.length,
      modified: first.readNullable<int>('series_modified') ?? 0,
    );
    return (
      item: item,
      artwork: title == null ? books.values.first.item : item,
      books: List.unmodifiable(books.values),
    );
  }

  /// Cheap per-page interruption check: one primary-key column read.
  Future<DownloadState?> stateOf(String jobId) async {
    final rows = await database
        .customSelect(
          'SELECT state FROM download_jobs WHERE id = ? AND account_id = ?',
          variables: [Variable(jobId), Variable(accountId)],
        )
        .get();
    return rows.isEmpty
        ? null
        : DownloadState.values.byName(rows.single.read<String>('state'));
  }

  /// Earliest retry time of a queued job, or null when nothing is queued.
  Future<int?> nextQueuedAt() async {
    final row = await database
        .customSelect(
          "SELECT MIN(retry_at) AS next FROM download_jobs WHERE account_id = ? AND state = 'queued'",
          variables: [Variable(accountId)],
        )
        .getSingle();
    return row.readNullable<int>('next');
  }

  Future<List<DownloadJob>> jobs() async =>
      (await database
              .customSelect(
                'SELECT * FROM download_jobs WHERE account_id = ? ORDER BY rowid',
                variables: [Variable(accountId)],
              )
              .get())
          .map(DownloadJob.new)
          .toList();
  Future<void> state(
    String jobId,
    DownloadState state, {
    String? error,
    int attempt = 0,
    int retryAt = 0,
  }) async {
    await database.customUpdate(
      'UPDATE download_jobs SET state = ?, error = ?, attempt = ?, retry_at = ? WHERE id = ? AND account_id = ?',
      variables: [
        Variable(state.name),
        Variable(error),
        Variable(attempt),
        Variable(retryAt),
        Variable(jobId),
        Variable(accountId),
      ],
      updates: {database.downloadJobs},
    );
  }

  Future<Map<int, DownloadAsset>> parts(String jobId) async {
    final saved = await job(jobId);
    if (saved == null) return {};
    final rows = await database
        .customSelect(
          'SELECT * FROM download_parts WHERE job_id = ?',
          variables: [Variable(jobId)],
        )
        .get();
    final parts = <int, DownloadAsset>{};
    for (final row in rows) {
      final page = row.read<int>('page_index');
      if (page < 0 ||
          page >= saved.manifest.assetCount ||
          row.read<String>('path') != file(jobId, page).path) {
        await forgetPart(jobId, page);
        continue;
      }
      parts[page] = DownloadAsset(
        file(jobId, page),
        row.read<String>('checksum'),
        row.read<String>('media_type'),
        row.read<int>('byte_length'),
      );
    }
    return parts;
  }

  Future<void> record(String jobId, int page, DownloadAsset asset) async {
    if (await stateOf(jobId) == null ||
        asset.file.path != file(jobId, page).path) {
      throw ArgumentError('Mismatched download part');
    }
    await database.customInsert(
      'INSERT OR REPLACE INTO download_parts (job_id, page_index, path, checksum, media_type, byte_length) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable(jobId),
        Variable(page),
        Variable(asset.file.path),
        Variable(asset.checksum),
        Variable(asset.mediaType),
        Variable(asset.byteLength),
      ],
      updates: {database.downloadParts},
    );
  }

  Future<void> forgetPart(String jobId, int page) => database.customStatement(
    'DELETE FROM download_parts WHERE job_id = ? AND page_index = ?',
    [jobId, page],
  );
  Future<void> clean(String jobId) async {
    if (await job(jobId) == null) return;
    await database.customStatement(
      'DELETE FROM download_parts WHERE job_id = ?',
      [jobId],
    );
    final folder = file(jobId, 0).parent;
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<void> recover() async {
    await directory.create(recursive: true);
    for (final job in await jobs()) {
      if (job.state == DownloadState.running ||
          job.state == DownloadState.verifying) {
        await state(job.id, DownloadState.queued);
      }
      if (job.state == DownloadState.complete ||
          job.state == DownloadState.cancelled) {
        await clean(job.id);
        continue;
      }
      final parts = await this.parts(job.id);
      for (final entry in parts.entries) {
        try {
          final asset = entry.value;
          if (await asset.file.length() != asset.byteLength ||
              asset.byteLength > pageBudget(job.manifest, entry.key) ||
              asset.byteLength > job.manifest.maximumAssetBytes) {
            throw const FormatException();
          }
          final inspected = await inspectDownloadAsset(
            asset.file,
            asset.mediaType,
            maximumBytes: pageBudget(job.manifest, entry.key),
          );
          if (inspected.checksum != asset.checksum) {
            throw const FormatException();
          }
        } catch (_) {
          await forgetPart(job.id, entry.key);
        }
      }
      final folder = file(job.id, 0).parent;
      if (await folder.exists()) {
        final kept = (await this.parts(job.id)).values
            .map((a) => a.file.path)
            .toSet();
        await for (final entity in folder.list(followLinks: false)) {
          if (entity is File && !kept.contains(entity.path)) {
            await entity.delete();
          }
        }
      }
    }
  }
}
