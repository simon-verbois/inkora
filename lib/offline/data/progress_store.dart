import '../../reader/domain/ebook_locator.dart';

import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../../reader/domain/reader_manifest.dart';
import '../domain/progress.dart';

ProgressIntent _intent(QueryRow row) => ProgressIntent(
  accountId: row.read<String>('account_id'),
  bookId: row.read<String>('book_id'),
  sequence: row.read<int>('sequence'),
  revision: row.read<String>('revision'),
  pageIndex: row.read<int>('page_index'),
  fraction: row.read<double>('fraction'),
  operation: ProgressOperation.values.byName(row.read<String>('operation')),
  state: row.read<String>('state'),
  attempt: row.read<int>('attempt'),
  retryAt: row.read<int>('retry_at'),
  pageCount: row.read<int>('page_count'),
  baseline: row.readNullable<String>('baseline') == null
      ? null
      : ProgressSnapshot.decode(row.read<String>('baseline')),
  documentLocator: row.readNullable<String>('document_locator'),
  remote: row.readNullable<String>('remote') == null
      ? null
      : ProgressSnapshot.decode(row.read<String>('remote')),
);

final class ProgressStore {
  ProgressStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;

  Future<void> seedServerLocator(
    ReaderManifest manifest,
    ProgressSnapshot remote,
  ) => database.transaction(() async {
    if (manifest.accountId != accountId ||
        remote.revision != manifest.revision) {
      throw ArgumentError('Mismatched progress snapshot');
    }
    final page = remote.completed
        ? manifest.pages.length - 1
        : remote.pageIndex ?? 0;
    manifest.key(page);
    final pending = await database
        .customSelect(
          'SELECT 1 FROM progress_events WHERE account_id = ? AND book_id = ? LIMIT 1',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .get();
    if (pending.isNotEmpty) return;
    final head = await database
        .customSelect(
          'SELECT baseline FROM progress_heads WHERE account_id = ? AND book_id = ?',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .getSingleOrNull();
    final baseline = head?.readNullable<String>('baseline');
    final changed =
        baseline == null ||
        !ProgressSnapshot.decode(baseline).sameVersion(remote);
    await observe(manifest.bookId, remote);
    await database.customUpdate(
      'INSERT INTO reader_positions (account_id, book_id, revision, page_index, fraction, document_locator) VALUES (?, ?, ?, ?, 0, ?) ON CONFLICT(account_id, book_id) DO UPDATE SET revision = excluded.revision, page_index = excluded.page_index, fraction = 0, document_locator = excluded.document_locator WHERE reader_positions.revision != excluded.revision OR ?',
      variables: [
        Variable(accountId),
        Variable(manifest.bookId),
        Variable(manifest.revision),
        Variable(page),
        Variable(remote.documentLocator),
        Variable(changed ? 1 : 0),
      ],
      updates: {database.readerPositions},
    );
  });

  Future<void> save(
    ReaderManifest manifest,
    ReaderLocator locator, {
    ProgressOperation operation = ProgressOperation.advance,
  }) => database.transaction(() async {
    if (manifest.accountId != accountId) {
      throw ArgumentError('Mismatched progress account');
    }
    manifest.key(locator.pageIndex);
    final current = await database
        .customSelect(
          'SELECT revision, page_index, fraction, document_locator FROM reader_positions WHERE account_id = ? AND book_id = ?',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .getSingleOrNull();
    if (operation == ProgressOperation.advance &&
        current != null &&
        current.read<String>('revision') == manifest.revision &&
        current.read<int>('page_index') == locator.pageIndex &&
        current.read<double>('fraction') == locator.fraction &&
        current.readNullable<String>('document_locator') ==
            locator.documentLocator) {
      return;
    }
    final head = await database
        .customSelect(
          'SELECT sequence, baseline FROM progress_heads WHERE account_id = ? AND book_id = ?',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .get();
    final sequence = (head.firstOrNull?.read<int>('sequence') ?? 0) + 1;
    final baseline = head.firstOrNull?.readNullable<String>('baseline');
    var page = locator.pageIndex;
    var documentLocator = locator.documentLocator;
    var eventFraction = locator.fraction;
    final tail = await database
        .customSelect(
          'SELECT * FROM progress_events WHERE account_id = ? AND book_id = ? ORDER BY sequence DESC LIMIT 1',
          variables: [Variable(accountId), Variable(manifest.bookId)],
        )
        .get();
    if (operation == ProgressOperation.advance && tail.isNotEmpty) {
      final previous = _intent(tail.single);
      if (previous.operation == ProgressOperation.advance &&
          previous.revision == manifest.revision &&
          previous.state == 'queued') {
        if (previous.pageIndex > page ||
            (previous.pageIndex == page &&
                previous.documentLocator != null &&
                documentLocator != null &&
                EbookLocator.decode(previous.documentLocator!).progression >
                    EbookLocator.decode(documentLocator).progression)) {
          page = previous.pageIndex;
          documentLocator = previous.documentLocator;
          eventFraction = previous.fraction;
        }
        await database.customStatement(
          'DELETE FROM progress_events WHERE account_id = ? AND book_id = ? AND sequence = ?',
          [accountId, manifest.bookId, previous.sequence],
        );
      }
    }
    await database.customStatement(
      'INSERT OR REPLACE INTO reader_positions (account_id, book_id, revision, page_index, fraction, document_locator) VALUES (?, ?, ?, ?, ?, ?)',
      [
        accountId,
        manifest.bookId,
        manifest.revision,
        locator.pageIndex,
        locator.fraction,
        locator.documentLocator,
      ],
    );
    await database.customStatement(
      'INSERT OR REPLACE INTO progress_heads (account_id, book_id, sequence, baseline) VALUES (?, ?, ?, ?)',
      [accountId, manifest.bookId, sequence, baseline],
    );
    await database.customInsert(
      'INSERT INTO progress_events (account_id, book_id, sequence, revision, page_index, fraction, operation, baseline, state, page_count, document_locator) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable(accountId),
        Variable(manifest.bookId),
        Variable(sequence),
        Variable(manifest.revision),
        Variable(page),
        Variable(eventFraction),
        Variable(operation.name),
        Variable(baseline),
        const Variable('queued'),
        Variable(manifest.pages.length),
        Variable(documentLocator),
      ],
      updates: {database.progressEvents},
    );
  });
  Future<List<ProgressIntent>> pending() async =>
      (await database
              .customSelect(
                'SELECT * FROM progress_events WHERE account_id = ? ORDER BY book_id, sequence',
                variables: [Variable(accountId)],
              )
              .get())
          .map(_intent)
          .toList();
  Future<ProgressIntent?> intent(String book, int sequence) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM progress_events WHERE account_id = ? AND book_id = ? AND sequence = ?',
          variables: [Variable(accountId), Variable(book), Variable(sequence)],
        )
        .get();
    return rows.isEmpty ? null : _intent(rows.single);
  }

  Stream<List<ProgressIntent>> watch() => database
      .customSelect(
        'SELECT * FROM progress_events WHERE account_id = ? ORDER BY book_id, sequence',
        variables: [Variable(accountId)],
        readsFrom: {database.progressEvents},
      )
      .watch()
      .map((rows) => rows.map(_intent).toList());
  Future<void> recover() => database.customStatement(
    "UPDATE progress_events SET state = 'queued' WHERE account_id = ? AND state = 'sending'",
    [accountId],
  );
  Future<void> observe(String book, ProgressSnapshot remote) async {
    await database.customUpdate(
      'INSERT INTO progress_heads (account_id, book_id, sequence, baseline) VALUES (?, ?, 0, ?) ON CONFLICT(account_id, book_id) DO UPDATE SET baseline = excluded.baseline',
      variables: [
        Variable(accountId),
        Variable(book),
        Variable(remote.encode()),
      ],
      updates: {database.progressHeads},
    );
  }

  Future<void> acknowledge(
    ProgressIntent event,
    ProgressSnapshot remote, {
    bool advanceFollowingBaseline = false,
  }) => database.transaction(() async {
    _check(event);
    await observe(event.bookId, remote);
    await database.customUpdate(
      'DELETE FROM progress_events WHERE account_id = ? AND book_id = ? AND sequence = ?',
      variables: [
        Variable(accountId),
        Variable(event.bookId),
        Variable(event.sequence),
      ],
      updates: {database.progressEvents},
    );
    // Only an explained local write can advance later intent baselines. Merely
    // observing a concurrent advance must not erase an offline rewind conflict.
    if (advanceFollowingBaseline) {
      await database.customStatement(
        "UPDATE progress_events SET baseline = ? WHERE account_id = ? AND book_id = ? AND sequence > ? AND baseline IS ? AND state = 'queued'",
        [
          remote.encode(),
          accountId,
          event.bookId,
          event.sequence,
          event.baseline?.encode(),
        ],
      );
    }
  });
  Future<void> state(
    ProgressIntent event,
    String state, {
    ProgressSnapshot? remote,
    int attempt = 0,
    int retryAt = 0,
  }) async {
    _check(event);
    await database.customUpdate(
      'UPDATE progress_events SET state = ?, remote = ?, attempt = ?, retry_at = ? WHERE account_id = ? AND book_id = ? AND sequence = ?',
      variables: [
        Variable(state),
        Variable(remote?.encode()),
        Variable(attempt),
        Variable(retryAt),
        Variable(accountId),
        Variable(event.bookId),
        Variable(event.sequence),
      ],
      updates: {database.progressEvents},
    );
  }

  void _check(ProgressIntent event) {
    if (event.accountId != accountId) {
      throw ArgumentError('Mismatched outbox account');
    }
  }

  Future<void> resolve(ProgressIntent event, {required bool keepLocal}) =>
      database.transaction(() async {
        _check(event);
        final current = (await pending())
            .where(
              (e) => e.bookId == event.bookId && e.sequence == event.sequence,
            )
            .firstOrNull;
        if (current == null ||
            current.state != 'conflict' ||
            current.remote == null) {
          return;
        }
        final remote = current.remote!;
        if (keepLocal) {
          if (remote.revision != current.revision) {
            throw StateError(
              'Refresh the book before remapping a changed revision',
            );
          }
          await database.customUpdate(
            "UPDATE progress_events SET baseline = ?, state = 'queued', remote = NULL, retry_at = 0, attempt = 0 WHERE account_id = ? AND book_id = ? AND sequence = ?",
            variables: [
              Variable(remote.encode()),
              Variable(accountId),
              Variable(event.bookId),
              Variable(event.sequence),
            ],
            updates: {database.progressEvents},
          );
        } else {
          await acknowledge(current, remote);
          final head = await database
              .customSelect(
                'SELECT sequence FROM progress_heads WHERE account_id = ? AND book_id = ?',
                variables: [Variable(accountId), Variable(event.bookId)],
              )
              .getSingle();
          if (head.read<int>('sequence') == event.sequence) {
            await database.customStatement(
              'UPDATE reader_positions SET revision = ?, page_index = ?, fraction = 0, document_locator = ? WHERE account_id = ? AND book_id = ?',
              [
                remote.revision,
                remote.pageIndex ?? 0,
                remote.documentLocator,
                accountId,
                event.bookId,
              ],
            );
          }
        }
      });
}
