import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../domain/reader_manifest.dart';

final class ReadingHistoryStore {
  ReadingHistoryStore(this.database, this.account);
  final AppDatabase database;
  final String account;
  Future<void> opened(ReaderManifest manifest) async {
    if (manifest.accountId != account) {
      throw ArgumentError('Mismatched account');
    }
    await database.transaction(() async {
      await database.customUpdate(
        'INSERT INTO reading_history (account_id, book_id, title, opened_at) VALUES (?,?,?,?) ON CONFLICT(account_id,book_id) DO UPDATE SET title=excluded.title, opened_at=excluded.opened_at',
        variables: [
          Variable(account),
          Variable(manifest.bookId),
          Variable(manifest.title),
          Variable(DateTime.now().toUtc()),
        ],
        updates: {database.readingHistory},
      );
      await database.customUpdate(
        'DELETE FROM reading_history WHERE account_id=? AND book_id NOT IN (SELECT book_id FROM reading_history WHERE account_id=? ORDER BY opened_at DESC, book_id LIMIT 500)',
        variables: [Variable(account), Variable(account)],
        updates: {database.readingHistory},
      );
    });
  }

  Stream<List<ReadingHistoryData>> watch(int limit) =>
      (database.select(database.readingHistory)
            ..where((r) => r.accountId.equals(account))
            ..orderBy([
              (r) => OrderingTerm.desc(r.openedAt),
              (r) => OrderingTerm.asc(r.bookId),
            ])
            ..limit(limit))
          .watch();
  Future<void> clear() => (database.delete(
    database.readingHistory,
  )..where((r) => r.accountId.equals(account))).go();
}
