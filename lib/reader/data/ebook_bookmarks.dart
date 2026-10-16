import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../domain/ebook_locator.dart';

final class EbookBookmarks {
  EbookBookmarks(this.database, String account, String book)
    : key = 'ebook-bookmarks:${jsonEncode([account, book])}';
  final AppDatabase database;
  final String key;
  Future<List<EbookLocator>> read() async {
    final row = await database
        .customSelect(
          'SELECT payload FROM app_preferences WHERE key = ?',
          variables: [Variable(key)],
        )
        .getSingleOrNull();
    if (row == null) return [];
    return _decodeBookmarks(row.read<String>('payload'));
  }

  /// Serialize mutation/read/write across instances through the existing DB.
  Future<List<EbookLocator>> add(EbookLocator bookmark) =>
      database.transaction(() async {
        final current = await read();
        final next = await _addUnique(current, bookmark);
        if (next == null) return current;
        await write(next);
        return next;
      });

  Future<List<EbookLocator>> remove(EbookLocator bookmark) =>
      database.transaction(() async {
        final current = await read();
        final next = await _without(current, bookmark);
        if (next.length != current.length) await write(next);
        return next;
      });

  Future<void> write(List<EbookLocator> bookmarks) async {
    if (bookmarks.length > 200) {
      throw const FormatException('Bookmark limit reached');
    }
    final payload = await _encodeBookmarks(bookmarks);
    await database.customUpdate(
      'INSERT INTO app_preferences (key, payload) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET payload = excluded.payload WHERE app_preferences.payload != excluded.payload',
      variables: [Variable(key), Variable(payload)],
      updates: {database.appPreferences},
    );
  }
}

Future<List<EbookLocator>> _decodeBookmarks(String payload) => Isolate.run(() {
  final list = jsonDecode(payload) as List;
  return list
      .take(200)
      .map((e) => EbookLocator(Map<String, dynamic>.from(e as Map)))
      .toList();
});
Future<String> _encodeBookmarks(List<EbookLocator> bookmarks) =>
    Isolate.run(() => jsonEncode(bookmarks.map((e) => e.value).toList()));

Future<List<EbookLocator>?> _addUnique(
  List<EbookLocator> current,
  EbookLocator bookmark,
) => Isolate.run(() {
  final key = bookmark.bookmarkKey;
  return current.any((value) => value.bookmarkKey == key)
      ? null
      : [...current, bookmark];
});
Future<List<EbookLocator>> _without(
  List<EbookLocator> current,
  EbookLocator bookmark,
) => Isolate.run(() {
  final key = bookmark.bookmarkKey;
  return current.where((value) => value.bookmarkKey != key).toList();
});
