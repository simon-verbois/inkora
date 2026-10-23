import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../../features/library/data/catalogue_store.dart';

/// Opt-in per-series policy and conservative completion timestamps. Reuses
/// account-owned preference rows; no polling, network or filesystem scans.
final class DownloadRetentionStore {
  DownloadRetentionStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;
  static const delay = Duration(hours: 24);
  static const policyScope = 'downloadRetentionSeries';
  static const completionScope = 'downloadRetentionCompleted';

  Future<bool> enabled(String series) async =>
      (await database
              .customSelect(
                'SELECT payload FROM reading_preferences WHERE account_id=? AND scope=? AND scope_id=?',
                variables: [
                  Variable(accountId),
                  const Variable(policyScope),
                  Variable(series),
                ],
              )
              .getSingleOrNull())
          ?.read<String>('payload') ==
      'true';

  Future<void> configure(String series, bool enabled) => database.customUpdate(
    '''INSERT INTO reading_preferences(account_id,scope,scope_id,payload) VALUES (?,?,?,?)
    ON CONFLICT(account_id,scope,scope_id) DO UPDATE SET payload=excluded.payload
    WHERE reading_preferences.payload<>excluded.payload''',
    variables: [
      Variable(accountId),
      const Variable(policyScope),
      Variable(series),
      Variable(enabled ? 'true' : 'false'),
    ],
    updates: {database.readingPreferences},
  );

  /// Called only when the progress classification changes. Restarting a book
  /// discards its old deadline, even if it is finished again before next launch.
  Future<void> readingStateChanged(String book, {DateTime? now}) =>
      database.transaction(() async {
        await database.customStatement(
          '''DELETE FROM reading_preferences WHERE account_id=? AND scope=? AND scope_id=?''',
          [accountId, completionScope, book],
        );
        await database.customStatement(
          '''INSERT INTO reading_preferences(account_id,scope,scope_id,payload)
      SELECT ?,?,?,? WHERE EXISTS(SELECT 1 FROM book_reading_states
      WHERE account_id=? AND book_id=? AND status='completed')''',
          [
            accountId,
            completionScope,
            book,
            (now ?? DateTime.now()).millisecondsSinceEpoch.toString(),
            accountId,
            book,
          ],
        );
      });

  /// Only complete downloads in opted-in series participate. A server-only or
  /// legacy completion starts its grace period at first observation. SQL uses
  /// account/scope and account/book primary keys plus catalogue browse indexes.
  Future<List<({String jobId, String bookId})>> due({
    DateTime? now,
    String? jobId,
  }) => database.transaction(() async {
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await database
        .customSelect(
          '''SELECT j.id,j.book_id,
      ${CatalogueStore.readingState('j', id: 'book_id', metadata: 'b.descriptive_metadata')} AS status,
      t.payload AS completed_at
      FROM download_jobs j
      LEFT JOIN catalogue_snapshots s ON s.account_id=j.account_id
      LEFT JOIN catalogue_entries b ON b.account_id=j.account_id AND b.generation=s.generation AND b.kind='book' AND b.remote_id=j.book_id
      JOIN reading_preferences p ON p.account_id=j.account_id AND p.scope=?
        AND p.scope_id=COALESCE(b.series_id,json_extract(j.manifest,'\$.seriesId')) AND p.payload='true'
      LEFT JOIN reading_preferences t ON t.account_id=j.account_id AND t.scope=? AND t.scope_id=j.book_id
      WHERE j.account_id=? AND j.state='complete' ${jobId == null ? '' : 'AND j.id=?'} ''',
          variables: [
            const Variable(policyScope),
            const Variable(completionScope),
            Variable(accountId),
            if (jobId != null) Variable(jobId),
          ],
        )
        .get();
    final due = <({String jobId, String bookId})>[];
    for (final row in rows) {
      final book = row.read<String>('book_id');
      final completed = row.read<String>('status') == 'completed';
      final since = int.tryParse(
        row.readNullable<String>('completed_at') ?? '',
      );
      if (!completed) {
        if (since != null) {
          await database.customStatement(
            'DELETE FROM reading_preferences WHERE account_id=? AND scope=? AND scope_id=?',
            [accountId, completionScope, book],
          );
        }
      } else if (since == null) {
        await database.customStatement(
          'INSERT OR IGNORE INTO reading_preferences(account_id,scope,scope_id,payload) VALUES (?,?,?,?)',
          [accountId, completionScope, book, time.toString()],
        );
      } else if (time - since >= delay.inMilliseconds) {
        due.add((jobId: row.read<String>('id'), bookId: book));
      }
    }
    return due;
  });
}
