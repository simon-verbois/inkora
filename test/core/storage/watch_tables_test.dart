import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';

void main() {
  test('table watches with different sets never share one stream', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var history = 0, preferences = 0;
    final first = watchTables(database, {
      database.readingHistory,
    }).listen((_) => history++);
    final second = watchTables(database, {
      database.appPreferences,
    }).listen((_) => preferences++);
    addTearDown(first.cancel);
    addTearDown(second.cancel);
    await pumpEventQueue();
    expect((history, preferences), (1, 1));
    await database.customInsert(
      'INSERT INTO reading_history (account_id, book_id, title, opened_at) VALUES (?, ?, ?, ?)',
      variables: [
        const Variable('a'),
        const Variable('b'),
        const Variable('t'),
        Variable(DateTime.utc(2026)),
      ],
      updates: {database.readingHistory},
    );
    await pumpEventQueue();
    // With a shared constant SELECT 1 the second registration would have
    // reused the first stream's tables and missed this write.
    expect((history, preferences), (2, 1));
    await database.customInsert(
      "INSERT INTO app_preferences (key, payload) VALUES ('k', 'v')",
      updates: {database.appPreferences},
    );
    await pumpEventQueue();
    expect((history, preferences), (2, 2));
  });
}
