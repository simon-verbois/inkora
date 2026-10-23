import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Non-secret profile metadata. Credentials belong in native secure storage.
class ServerProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get baseUrl => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Immutable staging/published snapshots. Account includes server and user identity.
class CatalogueEntries extends Table {
  TextColumn get accountId => text()();
  TextColumn get generation => text()();
  TextColumn get kind => text()();
  TextColumn get remoteId => text()();
  TextColumn get title => text()();
  TextColumn get sortTitle => text()();
  TextColumn get summary => text()();
  TextColumn get searchText => text()();
  TextColumn get libraryId => text().nullable()();
  TextColumn get seriesId => text().nullable()();
  RealColumn get number => real()();
  IntColumn get itemCount => integer()();
  IntColumn get pageCount => integer()();
  IntColumn get modified => integer()();
  BoolColumn get deleted => boolean()();
  BoolColumn get available => boolean()();
  BoolColumn get ordered => boolean()();
  TextColumn get descriptiveMetadata =>
      text().withDefault(const Constant('{}'))();
  @override
  Set<Column<Object>> get primaryKey => {accountId, generation, kind, remoteId};
}

class CatalogueMemberships extends Table {
  TextColumn get accountId => text()();
  TextColumn get generation => text()();
  TextColumn get groupKind => text()();
  TextColumn get groupId => text()();
  TextColumn get itemKind => text()();
  TextColumn get itemId => text()();
  IntColumn get position => integer()();
  BoolColumn get removed => boolean()();
  @override
  Set<Column<Object>> get primaryKey => {
    accountId,
    generation,
    groupKind,
    groupId,
    itemId,
  };
}

class CatalogueSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get generation => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

@DataClassName('StoredReaderManifest')
class ReaderManifests extends Table {
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId};
}

class ReaderAssets extends Table {
  TextColumn get assetId => text()();
  TextColumn get tier => text()();
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get revision => text()();
  IntColumn get pageIndex => integer()();
  TextColumn get representation => text()();
  TextColumn get checksum => text()();
  TextColumn get mediaType => text()();
  IntColumn get byteLength => integer()();
  DateTimeColumn get lastAccess => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {assetId, tier};
}

/// Published only after every file in a complete download has been verified.
class ReaderDownloads extends Table {
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get revision => text()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId, revision};
}

class ReadingPreferences extends Table {
  TextColumn get accountId => text()();
  TextColumn get scope => text()();
  TextColumn get scopeId => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, scope, scopeId};
}

class ReaderPositions extends Table {
  TextColumn get documentLocator => text().nullable()();
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get revision => text()();
  IntColumn get pageIndex => integer()();
  RealColumn get fraction => real()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId};
}

class OfflineSettings extends Table {
  TextColumn get accountId => text()();
  IntColumn get quota => integer()();
  BoolColumn get wifiOnly => boolean()();
  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

class DownloadJobs extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get revision => text()();
  TextColumn get manifest => text()();
  TextColumn get state => text()();
  IntColumn get reservedBytes => integer()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get retryAt => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadParts extends Table {
  TextColumn get jobId => text()();
  IntColumn get pageIndex => integer()();
  TextColumn get path => text()();
  TextColumn get checksum => text()();
  TextColumn get mediaType => text()();
  IntColumn get byteLength => integer()();
  @override
  Set<Column<Object>> get primaryKey => {jobId, pageIndex};
}

class ProgressHeads extends Table {
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  IntColumn get sequence => integer()();
  TextColumn get baseline => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId};
}

class ProgressEvents extends Table {
  TextColumn get documentLocator => text().nullable()();
  IntColumn get pageCount => integer()();
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  IntColumn get sequence => integer()();
  TextColumn get revision => text()();
  IntColumn get pageIndex => integer()();
  RealColumn get fraction => real()();
  TextColumn get operation => text()();
  TextColumn get baseline => text().nullable()();
  TextColumn get state => text()();
  TextColumn get remote => text().nullable()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();
  IntColumn get retryAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId, sequence};
}

/// Device appearance/accessibility preferences; never stores credentials.
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Account-scoped server reading shelf, independently refreshed from catalogue.
class ResumeSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

/// Only changes when effective unread/in-progress/completed state changes.
class BookReadingStates extends Table {
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get status => text()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId};
}

class ReadingHistory extends Table {
  TextColumn get accountId => text()();
  TextColumn get bookId => text()();
  TextColumn get title => text()();
  DateTimeColumn get openedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {accountId, bookId};
}

@DriftDatabase(
  tables: [
    ServerProfiles,
    CatalogueEntries,
    CatalogueMemberships,
    CatalogueSnapshots,
    ReaderManifests,
    ReaderAssets,
    ReaderDownloads,
    ReadingPreferences,
    ReaderPositions,
    OfflineSettings,
    DownloadJobs,
    DownloadParts,
    ProgressHeads,
    ProgressEvents,
    AppPreferences,
    ResumeSnapshots,
    ReadingHistory,
    BookReadingStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 11) {
        await migrator.createTable(readingHistory);
        await migrator.createTable(bookReadingStates);
      }
      if (from < 2) {
        await migrator.createTable(catalogueEntries);
        await migrator.createTable(catalogueMemberships);
        await migrator.createTable(catalogueSnapshots);
      }
      if (from < 3) {
        await migrator.createTable(readerManifests);
        await migrator.createTable(readerAssets);
        await migrator.createTable(readerDownloads);
        await migrator.createTable(readingPreferences);
        await migrator.createTable(readerPositions);
      }
      if (from < 4) {
        await migrator.createTable(offlineSettings);
        await migrator.createTable(downloadJobs);
        await migrator.createTable(downloadParts);
        await migrator.createTable(progressHeads);
        await migrator.createTable(progressEvents);
      }
      if (from < 5) await migrator.createTable(appPreferences);
      if (from < 6) await migrator.createTable(resumeSnapshots);
      if (from >= 2 && from < 7) {
        // An interrupted development upgrade can leave the new column with
        // the previous user_version. Preserve its data instead of adding twice.
        final columns = await customSelect(
          'PRAGMA table_info(catalogue_entries)',
        ).get();
        if (!columns.any(
          (row) => row.read<String>('name') == 'descriptive_metadata',
        )) {
          await migrator.addColumn(
            catalogueEntries,
            catalogueEntries.descriptiveMetadata,
          );
        }
      }
      if (from >= 3 && from < 10) {
        final columns = await customSelect(
          'PRAGMA table_info(reader_positions)',
        ).get();
        if (!columns.any(
          (row) => row.read<String>('name') == 'document_locator',
        )) {
          await migrator.addColumn(
            readerPositions,
            readerPositions.documentLocator,
          );
        }
      }
      if (from >= 4 && from < 10) {
        final columns = await customSelect('PRAGMA table_info(progress_events)')
            .get();
        if (!columns.any(
          (row) => row.read<String>('name') == 'document_locator',
        )) {
          await migrator.addColumn(
            progressEvents,
            progressEvents.documentLocator,
          );
        }
      }
      if (from < 9) {
        // v8 was installed during favorites development. Advance the schema
        // rather than downgrading or recreating unrelated account/reader data.
        await customStatement('DROP TABLE IF EXISTS favorite_series');
        await customStatement(
          "DELETE FROM app_preferences WHERE substr(key, 1, 15) = 'favorites-sync:'",
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS download_retention_jobs ON download_jobs(account_id, state, book_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS reading_history_recent ON reading_history(account_id, opened_at DESC, book_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_browse ON catalogue_entries(account_id, generation, kind, library_id, sort_title, remote_id)',
      );
      await customStatement(
        "CREATE INDEX IF NOT EXISTS catalogue_document_books ON catalogue_entries(account_id, generation, kind, COALESCE(json_extract(descriptive_metadata, '\$.mediaType'), ''), series_id, remote_id)",
      );
      // Mixed ebook/comic presentation sorts across kinds within one snapshot.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_reading_title ON catalogue_entries(account_id, generation, sort_title, remote_id, kind)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_reading_modified ON catalogue_entries(account_id, generation, modified DESC, remote_id, kind)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_series_books ON catalogue_entries(account_id, generation, kind, series_id, number, remote_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS reader_cache_lru ON reader_assets(tier, last_access)',
      );
      // Unfiltered all-library browse orders (title and recently updated).
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_title ON catalogue_entries(account_id, generation, kind, sort_title, remote_id)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS catalogue_modified ON catalogue_entries(account_id, generation, kind, modified, remote_id)',
      );
      // Per-book download asset publication/removal/verification.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS reader_assets_book ON reader_assets(tier, account_id, book_id, revision)',
      );
    },
  );
}

/// Open durable metadata storage away from evictable platform cache folders.
Future<AppDatabase> openAppDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final file = File.fromUri(directory.uri.resolve('inkora.sqlite'));
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      // WAL lets reads proceed during the frequent small locator/outbox/cache
      // index writes; NORMAL synchronous mode stays durable across app crashes
      // under WAL (only OS crash/power loss may roll back the latest commits).
      setup: (database) => database
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA synchronous = NORMAL')
        ..execute('PRAGMA temp_store = MEMORY'),
    ),
  );
}

/// Emits once, then after every write to [tables]. Drift shares the stream of
/// identical SQL text regardless of `readsFrom`, so a constant `SELECT 1`
/// with different table sets would silently reuse the first registration's
/// tables. The statement therefore names its sorted table set.
Stream<void> watchTables(
  AppDatabase database,
  Set<ResultSetImplementation<dynamic, dynamic>> tables,
) {
  final names = [for (final table in tables) table.entityName]..sort();
  return database
      .customSelect(
        "SELECT '${names.join(',')}' AS watched_tables",
        readsFrom: tables,
      )
      .watch()
      .map((_) {});
}
