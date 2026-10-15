import 'dart:convert';

import '../../../core/storage/app_database.dart';

/// A null selection follows all current and future accessible libraries.
/// An explicit empty selection intentionally hides the entire catalogue.
final class LibraryVisibilityStore {
  LibraryVisibilityStore(this.database, this.accountId);
  final AppDatabase database;
  final String accountId;
  String get key => 'library-visibility:$accountId';

  Future<String?> payload() async => (await (database.select(
    database.appPreferences,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.payload;

  static Set<String>? decode(String? payload) => payload == null
      ? null
      : (jsonDecode(payload) as List).cast<String>().toSet();

  Stream<Set<String>?> watch() =>
      (database.select(database.appPreferences)
            ..where((row) => row.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.payload)
          .distinct()
          .map(decode);

  Future<void> save(Set<String>? included) => database.transaction(() async {
    final ids = included == null ? null : (included.toList()..sort());
    final next = ids == null ? null : jsonEncode(ids);
    if (await payload() == next) return;
    if (next == null) {
      await (database.delete(
        database.appPreferences,
      )..where((row) => row.key.equals(key))).go();
    } else {
      await database
          .into(database.appPreferences)
          .insertOnConflictUpdate(
            AppPreferencesCompanion.insert(key: key, payload: next),
          );
    }
  });

  static String _selection(String alias) =>
      "(SELECT payload FROM app_preferences WHERE key='library-visibility:' || $alias.account_id)";

  /// Library availability comes from the authenticated libraries endpoint.
  /// Unknown parents remain usable before the first complete snapshot; known
  /// revoked libraries are excluded even when historical metadata is retained.
  static String libraryPredicate(String alias, String libraryId) =>
      '''
    (NOT EXISTS (SELECT 1 FROM catalogue_entries denied
      WHERE denied.account_id=$alias.account_id AND denied.generation=$alias.generation
        AND denied.kind='library' AND denied.remote_id=$libraryId
        AND (denied.available=0 OR denied.deleted=1))
     AND (${_selection(alias)} IS NULL OR $libraryId IN
       (SELECT value FROM json_each(${_selection(alias)}))))
  ''';

  static String predicate(String alias) =>
      '''
    CASE WHEN $alias.kind='library' THEN
      $alias.available=1 AND $alias.deleted=0
      AND ${libraryPredicate(alias, '$alias.remote_id')}
    WHEN $alias.kind IN ('series', 'book') THEN
      ${libraryPredicate(alias, '$alias.library_id')}
    ELSE ${_selection(alias)} IS NULL OR EXISTS (
      SELECT 1 FROM catalogue_memberships visible_members
      JOIN catalogue_entries visible_child
        ON visible_child.account_id=visible_members.account_id
        AND visible_child.generation=visible_members.generation
        AND visible_child.kind=visible_members.item_kind
        AND visible_child.remote_id=visible_members.item_id
      WHERE visible_members.account_id=$alias.account_id
        AND visible_members.generation=$alias.generation
        AND visible_members.group_kind=$alias.kind
        AND visible_members.group_id=$alias.remote_id
        AND visible_members.removed=0
        AND visible_child.available=1 AND visible_child.deleted=0
        AND ${libraryPredicate('visible_child', 'visible_child.library_id')}) END
  ''';
}
