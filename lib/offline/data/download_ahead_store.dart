import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../../features/library/data/library_visibility_store.dart';

/// Account-owned opt-in rules. Only classification changes (not page writes)
/// and catalogue publications recalculate the small desired download window.
final class DownloadAheadStore {
  DownloadAheadStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;
  static const scope = 'downloadAheadSeries';

  Future<int> count(String series) async {
    final row = await database
        .customSelect(
          'SELECT payload FROM reading_preferences WHERE account_id=? AND scope=? AND scope_id=?',
          variables: [
            Variable(accountId),
            const Variable(scope),
            Variable(series),
          ],
        )
        .getSingleOrNull();
    final value = int.tryParse(row?.read<String>('payload') ?? '');
    return value == 2 || value == 3 ? value! : 0;
  }

  Future<void> configure(String series, int count) {
    if (count != 0 && count != 2 && count != 3) {
      throw ArgumentError.value(count, 'count');
    }
    return database.customUpdate(
      '''INSERT INTO reading_preferences(account_id,scope,scope_id,payload)
      VALUES (?,?,?,?) ON CONFLICT(account_id,scope,scope_id) DO UPDATE SET payload=excluded.payload
      WHERE reading_preferences.payload<>excluded.payload''',
      variables: [
        Variable(accountId),
        const Variable(scope),
        Variable(series),
        Variable('$count'),
      ],
      updates: {database.readingPreferences},
    );
  }

  /// Include already downloaded/queued books in the window, so they never
  /// cause the rule to run past its limit. A paused/cancelled job stays manual.
  Stream<List<String>> watchTargets() => database
      .customSelect(
        '''
    WITH volumes AS (
      SELECT e.remote_id,e.series_id,e.number,e.sort_title,CAST(p.payload AS INTEGER) AS keep_count,
        COALESCE(r.status,json_extract(e.descriptive_metadata,'\$.readingStatus'),'unread') AS status
      FROM reading_preferences p
      JOIN catalogue_snapshots s ON s.account_id=p.account_id
      JOIN catalogue_entries e ON e.account_id=s.account_id AND e.generation=s.generation
        AND e.kind='book' AND e.series_id=p.scope_id
      LEFT JOIN book_reading_states r ON r.account_id=e.account_id AND r.book_id=e.remote_id
      WHERE p.account_id=? AND p.scope=? AND p.payload IN ('2','3')
        AND e.available=1 AND e.deleted=0
        AND ${LibraryVisibilityStore.predicate('e')}
        AND (e.page_count>0 OR json_extract(e.descriptive_metadata,'\$.mediaType') IN ('application/pdf','application/epub+zip'))
    ), ordered AS (
      SELECT *,ROW_NUMBER() OVER(PARTITION BY series_id ORDER BY number,sort_title,remote_id) AS position
      FROM volumes
    ), anchored AS (
      SELECT *,COALESCE(
        MIN(CASE WHEN status='inProgress' THEN position END) OVER(PARTITION BY series_id),
        MAX(CASE WHEN status='completed' THEN position END) OVER(PARTITION BY series_id)+1,1) AS current_position
      FROM ordered
    ), unfinished AS (
      SELECT *,ROW_NUMBER() OVER(PARTITION BY series_id ORDER BY position) AS ahead
      FROM anchored WHERE status<>'completed' AND (current_position IS NULL OR position>=current_position)
    ) SELECT remote_id FROM unfinished WHERE ahead<=keep_count ORDER BY series_id,ahead
    ''',
        variables: [Variable(accountId), const Variable(scope)],
        readsFrom: {
          database.readingPreferences,
          database.catalogueSnapshots,
          database.bookReadingStates,
          database.appPreferences,
        },
      )
      .watch()
      .map((rows) => [for (final row in rows) row.read<String>('remote_id')])
      .distinct(
        (a, b) =>
            a.length == b.length &&
            List.generate(a.length, (i) => a[i] == b[i]).every((same) => same),
      );
}
