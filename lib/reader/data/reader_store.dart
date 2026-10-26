import 'dart:convert';

import 'manifest_codec.dart';

import '../../offline/data/progress_store.dart';

import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';

final class ReaderStore {
  ReaderStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;

  Future<ReaderManifest?> manifest(String bookId) async {
    final rows = await database
        .customSelect(
          'SELECT payload FROM reader_manifests WHERE account_id = ? AND book_id = ?',
          variables: [Variable(accountId), Variable(bookId)],
        )
        .get();
    if (rows.isEmpty) return null;
    try {
      final payload = rows.single.read<String>('payload');
      final manifest = payload.length > 256 * 1024
          ? await decodeReaderManifest(payload)
          : ReaderManifest.fromJson(
              jsonDecode(payload) as Map<String, dynamic>,
            );
      if (manifest.accountId != accountId || manifest.bookId != bookId) {
        return null;
      }
      return manifest;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveManifest(ReaderManifest manifest) async {
    if (manifest.accountId != accountId) {
      throw ArgumentError('Mismatched manifest account');
    }
    final payload = manifest.isDocument
        ? await encodeReaderManifest(manifest)
        : jsonEncode(manifest.toJson());
    await database.customStatement(
      'INSERT OR REPLACE INTO reader_manifests (account_id, book_id, payload) VALUES (?, ?, ?)',
      [accountId, manifest.bookId, payload],
    );
  }

  /// Membership test inside SQLite; the shelf payload is not decoded here.
  Future<bool> hasServerResume(String bookId) async {
    final rows = await database
        .customSelect(
          '''SELECT 1 FROM resume_snapshots s, json_each(s.payload, '\$.books') b
          WHERE s.account_id = ? AND json_extract(b.value, '\$.id') = ? LIMIT 1''',
          variables: [Variable(accountId), Variable(bookId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<ReaderLocator> locator(ReaderManifest manifest) async {
    final rows = await database
        .customSelect(
          'SELECT revision, page_index, fraction, document_locator FROM reader_positions WHERE account_id = ? AND book_id = ?',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .get();
    if (rows.isEmpty ||
        rows.single.read<String>('revision') != manifest.revision) {
      return ReaderLocator(0);
    }
    final row = rows.single;
    return ReaderLocator(
      row.read<int>('page_index').clamp(0, manifest.pages.length - 1),
      row.read<double>('fraction').clamp(0.0, 1.0),
      row.readNullable<String>('document_locator'),
    );
  }

  Future<void> saveLocator(
    ReaderManifest manifest,
    ReaderLocator locator,
  ) async {
    if (manifest.accountId != accountId) {
      throw ArgumentError('Mismatched locator account');
    }
    manifest.key(locator.pageIndex);
    await ProgressStore(database, accountId).save(manifest, locator);
  }

  Selectable<QueryRow> _preferences({
    String? libraryId,
    String? seriesId,
    String? bookId,
  }) => database.customSelect(
    '''SELECT scope, scope_id, payload FROM reading_preferences WHERE account_id = ?
      AND ((scope = 'global' AND scope_id = '')
        OR (scope = 'library' AND scope_id = ?)
        OR (scope = 'series' AND scope_id = ?)
        OR (scope = 'book' AND scope_id = ?))''',
    variables: [
      Variable(accountId),
      Variable(libraryId),
      Variable(seriesId),
      Variable(bookId),
    ],
    readsFrom: {database.readingPreferences},
  );

  Map<SettingsScope, ReadingOverrides> _layers(
    List<QueryRow> rows, {
    String? libraryId,
    String? seriesId,
    String? bookId,
  }) {
    final result = <SettingsScope, ReadingOverrides>{};
    for (final (scope, id) in [
      (SettingsScope.global, ''),
      (SettingsScope.library, libraryId),
      (SettingsScope.series, seriesId),
      (SettingsScope.book, bookId),
    ]) {
      if (id == null) continue;
      final row = rows
          .where(
            (row) =>
                row.read<String>('scope') == scope.name &&
                row.read<String>('scope_id') == id,
          )
          .firstOrNull;
      if (row != null) {
        result[scope] = ReadingOverrides.fromJson(
          jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
        );
      }
    }
    return result;
  }

  Future<Map<SettingsScope, ReadingOverrides>> preferenceLayers({
    String? libraryId,
    String? seriesId,
    String? bookId,
  }) async => _layers(
    await _preferences(
      libraryId: libraryId,
      seriesId: seriesId,
      bookId: bookId,
    ).get(),
    libraryId: libraryId,
    seriesId: seriesId,
    bookId: bookId,
  );

  Stream<ReadingSettings> settings(ReaderManifest manifest) =>
      _preferences(
        libraryId: manifest.libraryId,
        seriesId: manifest.seriesId,
        bookId: manifest.bookId,
      ).watch().map((rows) {
        final layers = _layers(
          rows,
          libraryId: manifest.libraryId,
          seriesId: manifest.seriesId,
          bookId: manifest.bookId,
        );
        if (manifest.isDocument) {
          final book = layers[SettingsScope.book] ?? const ReadingOverrides();
          final ebookConfigured = layers.values.any(
            (layer) => layer.mode == ReadingMode.ebook,
          );
          layers[SettingsScope.book] = ReadingOverrides.fromJson({
            ...book.toJson(),
            'mode': 'ebook',
            if (!ebookConfigured && book.background == null)
              'background': 'sepia',
          });
        }
        return effectiveSettings(manifest, layers);
      }).distinct();

  ReadingSettings effectiveSettings(
    ReaderManifest manifest,
    Map<SettingsScope, ReadingOverrides> layers,
  ) {
    final base = ReadingSettings.resolveScopes(layers);
    final analysis = layers[SettingsScope.book]?.spreadAnalysis;
    final rtl = base.direction == ReadingDirection.rightToLeft;
    return analysis != null && analysis.matches(manifest, rtl)
        ? ReadingSettings.resolveScopes(
            layers,
            automaticSpreadOffset: analysis.shifted,
          )
        : base;
  }

  /// Merge with the latest book draft: analysis must never erase a concurrent
  /// manual choice, and duplicate openings must not emit identical writes.
  Future<void> saveSpreadAnalysis(
    ReaderManifest manifest,
    SpreadPairingAnalysis analysis,
  ) async {
    if (manifest.accountId != accountId ||
        analysis.revision != manifest.revision) {
      throw ArgumentError('Mismatched spread analysis');
    }
    await database.transaction(() async {
      final book = await overrides(SettingsScope.book, manifest.bookId);
      if (book.spreadAnalysis?.matches(manifest, analysis.rightToLeft) ??
          false) {
        return;
      }
      await saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        ReadingOverrides.fromJson({
          ...book.toJson(),
          'spreadAnalysis': analysis.toJson(),
        }),
      );
    });
  }

  Stream<Map<String, ReadingOverrides>> libraryDefaults() => database
      .customSelect(
        "SELECT scope_id, payload FROM reading_preferences WHERE account_id = ? AND scope = 'library'",
        variables: [Variable(accountId)],
        readsFrom: {database.readingPreferences},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<String>('scope_id'): ReadingOverrides.fromJson(
              jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
            ),
        },
      );

  Future<ReadingOverrides> overrides(
    SettingsScope scope,
    String scopeId,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT payload FROM reading_preferences WHERE account_id = ? AND scope = ? AND scope_id = ?',
          variables: [
            Variable(accountId),
            Variable(scope.name),
            Variable(scopeId),
          ],
        )
        .get();
    return rows.isEmpty
        ? const ReadingOverrides()
        : ReadingOverrides.fromJson(
            jsonDecode(rows.single.read<String>('payload'))
                as Map<String, dynamic>,
          );
  }

  /// Flip the effective pairing in a transaction so consecutive presses cannot
  /// reuse an old settings-stream value. Preserve every other book override.
  Future<void> toggleSpreadOffset(ReaderManifest manifest) async {
    if (manifest.accountId != accountId) {
      throw ArgumentError('Mismatched pairing account');
    }
    await database.transaction(() async {
      final layers = await preferenceLayers(
        libraryId: manifest.libraryId,
        seriesId: manifest.seriesId,
        bookId: manifest.bookId,
      );
      final book = layers[SettingsScope.book] ?? const ReadingOverrides();
      final current = effectiveSettings(manifest, layers).spreadOffset;
      await saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        ReadingOverrides.fromJson({
          ...book.toJson(),
          'spreadOffset': !current,
          'spreadPairing': current ? 'unshifted' : 'shifted',
        }),
      );
    });
  }

  Future<void> saveOverrides(
    SettingsScope scope,
    String scopeId,
    ReadingOverrides overrides,
  ) async {
    ReadingSettings.resolve([overrides]);
    if (scope != SettingsScope.book && overrides.libraryDefaults) {
      throw ArgumentError('Library default binding belongs to a book');
    }
    if (scope != SettingsScope.global && scopeId.isEmpty) {
      throw ArgumentError('Missing settings scope');
    }
    final changed = await database.customUpdate(
      '''INSERT INTO reading_preferences (account_id, scope, scope_id, payload) VALUES (?, ?, ?, ?)
      ON CONFLICT(account_id, scope, scope_id) DO UPDATE SET payload = excluded.payload
      WHERE reading_preferences.payload <> excluded.payload''',
      variables: [
        Variable(accountId),
        Variable(scope.name),
        Variable(scope == SettingsScope.global ? '' : scopeId),
        Variable(jsonEncode(overrides.toJson())),
      ],
    );
    if (changed > 0) {
      database.notifyUpdates({
        TableUpdate.onTable(database.readingPreferences),
      });
    }
  }

  /// Save the chosen library defaults and clear descendant tuning atomically.
  /// Current catalogue membership wins over an old saved reader manifest.
  /// The manifest fallback also covers books opened/downloaded while offline.
  Future<void> applyLibraryDefaults(
    String libraryId,
    ReadingOverrides overrides,
  ) async {
    await database.transaction(() async {
      await saveOverrides(SettingsScope.library, libraryId, overrides);
      final changed = await database.customUpdate(
        '''WITH members AS (
          SELECT e.kind AS scope, e.remote_id AS id FROM catalogue_entries e
          JOIN catalogue_snapshots s ON s.account_id = e.account_id AND s.generation = e.generation
          WHERE e.account_id = ? AND e.library_id = ? AND e.kind IN ('series', 'book')
        ), offline_books AS (
          SELECT m.book_id AS id, json_extract(m.payload, '\$.seriesId') AS series_id
          FROM reader_manifests m WHERE m.account_id = ? AND json_extract(m.payload, '\$.libraryId') = ?
          AND NOT EXISTS (
            SELECT 1 FROM catalogue_entries e JOIN catalogue_snapshots s
              ON s.account_id = e.account_id AND s.generation = e.generation
            WHERE e.account_id = m.account_id AND e.kind = 'book' AND e.remote_id = m.book_id
          )
          AND NOT EXISTS (
            SELECT 1 FROM catalogue_entries e JOIN catalogue_snapshots s
              ON s.account_id = e.account_id AND s.generation = e.generation
            WHERE e.account_id = m.account_id AND e.kind = 'series'
              AND e.remote_id = json_extract(m.payload, '\$.seriesId') AND e.library_id <> ?
          )
        )
        DELETE FROM reading_preferences WHERE account_id = ? AND (
          (scope = 'book' AND scope_id IN (
            SELECT id FROM members WHERE scope = 'book' UNION SELECT id FROM offline_books))
          OR (scope = 'series' AND scope_id IN (
            SELECT id FROM members WHERE scope = 'series' UNION SELECT series_id FROM offline_books)))''',
        variables: [
          Variable(accountId),
          Variable(libraryId),
          Variable(accountId),
          Variable(libraryId),
          Variable(libraryId),
          Variable(accountId),
        ],
      );
      if (changed > 0) {
        database.notifyUpdates({
          TableUpdate.onTable(database.readingPreferences),
        });
      }
    });
  }
}
