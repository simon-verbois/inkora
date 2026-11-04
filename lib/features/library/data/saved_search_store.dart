import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/saved_catalogue_search.dart';

/// Small durable account-owned collection, excluded from reading settings
/// transfer. Named rows use the existing account/scope/id primary key.
final class SavedSearchStore {
  SavedSearchStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;
  static const scope = 'savedCatalogueSearch';
  static const maximum = 32;

  Stream<List<SavedCatalogueSearch>> watch() => database
      .customSelect(
        'SELECT scope_id,payload FROM reading_preferences WHERE account_id=? AND scope=? ORDER BY scope_id LIMIT 32',
        variables: [Variable(accountId), const Variable(scope)],
        readsFrom: {database.readingPreferences},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            (row.read<String>('scope_id'), row.read<String>('payload')),
        ],
      )
      .distinct(
        (a, b) =>
            a.length == b.length &&
            List.generate(a.length, (i) => a[i] == b[i]).every((same) => same),
      )
      .asyncMap(
        (rows) => Isolate.run(() {
          final searches = <SavedCatalogueSearch>[];
          for (final (name, payload) in rows) {
            if (payload.length > 8192) continue;
            try {
              final saved = SavedCatalogueSearch.fromJson(
                jsonDecode(payload) as Map<String, dynamic>,
              );
              if (saved.name == name) searches.add(saved);
            } catch (_) {
              /* A malformed row cannot hide other saved searches. */
            }
          }
          return searches;
        }),
      );

  Future<void> save(SavedCatalogueSearch search) => database.transaction(
    () async {
      // Validate lengths before encoding a pasted query on the UI isolate.
      SavedCatalogueSearch.fromJson(search.toJson());
      final payload = jsonEncode(search.toJson());
      if (payload.length > 8192) {
        throw const FormatException('Saved search too large');
      }
      final existing = await database
          .customSelect(
            'SELECT scope_id FROM reading_preferences WHERE account_id=? AND scope=? LIMIT 32',
            variables: [Variable(accountId), const Variable(scope)],
          )
          .get();
      if (existing.length >= maximum &&
          !existing.any((row) => row.read<String>('scope_id') == search.name)) {
        throw StateError('Saved search limit reached');
      }
      await database.customUpdate(
        '''INSERT INTO reading_preferences(account_id,scope,scope_id,payload) VALUES(?,?,?,?)
      ON CONFLICT(account_id,scope,scope_id) DO UPDATE SET payload=excluded.payload
      WHERE reading_preferences.payload<>excluded.payload''',
        variables: [
          Variable(accountId),
          const Variable(scope),
          Variable(search.name),
          Variable(payload),
        ],
        updates: {database.readingPreferences},
      );
    },
  );

  Future<void> remove(String name) => database.customUpdate(
    'DELETE FROM reading_preferences WHERE account_id=? AND scope=? AND scope_id=?',
    variables: [Variable(accountId), const Variable(scope), Variable(name)],
    updates: {database.readingPreferences},
  );
}
