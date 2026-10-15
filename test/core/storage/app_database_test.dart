import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';

void main() {
  test('profile schema round-trips without credential fields', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.serverProfiles)
        .insert(
          ServerProfilesCompanion.insert(
            id: 'server-1',
            displayName: 'Personal',
            baseUrl: 'https://example.test/komga/',
          ),
        );
    final profile = await database.select(database.serverProfiles).getSingle();
    expect(profile.id, 'server-1');
    expect(profile.baseUrl, 'https://example.test/komga/');
    expect(profile.displayName, 'Personal');
    await expectLater(
      database
          .into(database.serverProfiles)
          .insert(
            ServerProfilesCompanion.insert(
              id: 'server-1',
              displayName: 'Duplicate',
              baseUrl: 'https://other.test/',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    expect(database.schemaVersion, 10);
  });
}
