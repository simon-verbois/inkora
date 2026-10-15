import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/ui_preferences.dart';

final class UiPreferencesStore {
  UiPreferencesStore(this.database);
  final AppDatabase database;

  Stream<UiPreferences> watch() =>
      (database.select(database.appPreferences)
            ..where((row) => row.key.equals('ui')))
          .watchSingleOrNull()
          .distinct()
          .map((row) {
            if (row == null) return const UiPreferences();
            try {
              return UiPreferences.fromJson(
                jsonDecode(row.payload) as Map<String, dynamic>,
              );
            } catch (_) {
              return const UiPreferences();
            }
          });

  Future<void> update(UiPreferences Function(UiPreferences) change) =>
      database.transaction(() async {
        final row = await (database.select(
          database.appPreferences,
        )..where((row) => row.key.equals('ui'))).getSingleOrNull();
        UiPreferences current;
        try {
          current = row == null
              ? const UiPreferences()
              : UiPreferences.fromJson(
                  jsonDecode(row.payload) as Map<String, dynamic>,
                );
        } catch (_) {
          current = const UiPreferences();
        }
        await save(change(current));
      });

  Future<void> save(UiPreferences preferences) =>
      database.transaction(() async {
        final payload = jsonEncode(preferences.toJson());
        final previous = await (database.select(
          database.appPreferences,
        )..where((row) => row.key.equals('ui'))).getSingleOrNull();
        if (previous?.payload == payload) return;
        await database
            .into(database.appPreferences)
            .insertOnConflictUpdate(
              AppPreferencesCompanion.insert(key: 'ui', payload: payload),
            );
      });
}
