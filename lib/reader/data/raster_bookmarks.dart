import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/storage/app_database.dart';
import '../domain/reader_manifest.dart';

final class RasterBookmark {
  const RasterBookmark(this.revision, this.page, this.fraction, this.note);
  final String revision, note;
  final int page;
  final double fraction;
  ReaderLocator get locator => ReaderLocator(page, fraction);
  Map<String, Object> toJson() => {
    'revision': revision,
    'page': page,
    'fraction': fraction,
    'note': note,
  };
  factory RasterBookmark.fromJson(Map<String, dynamic> value) {
    final revision = value['revision'] as String;
    final page = value['page'] as int;
    final fraction = (value['fraction'] as num).toDouble();
    final note = value['note'] as String;
    if (revision.isEmpty ||
        page < 0 ||
        page >= 20000 ||
        !fraction.isFinite ||
        fraction < 0 ||
        fraction > 1 ||
        note.length > 500) {
      throw const FormatException('Invalid bookmark');
    }
    return RasterBookmark(revision, page, fraction, note);
  }
}

/// Uses the existing account/book preference boundary, like ebook bookmarks.
final class RasterBookmarks {
  RasterBookmarks(this.database, String account, String book)
    : key = 'raster-bookmarks:${jsonEncode([account, book])}';
  final AppDatabase database;
  final String key;
  Future<List<RasterBookmark>> read() async {
    final row = await database
        .customSelect(
          'SELECT payload FROM app_preferences WHERE key=?',
          variables: [Variable(key)],
        )
        .getSingleOrNull();
    if (row == null) return [];
    return (jsonDecode(row.read<String>('payload')) as List)
        .map(
          (e) => RasterBookmark.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> add(RasterBookmark bookmark) => database.transaction(() async {
    final current = await read();
    current.removeWhere(
      (v) =>
          v.revision == bookmark.revision &&
          v.page == bookmark.page &&
          (v.fraction - bookmark.fraction).abs() < .001,
    );
    if (current.length >= 200) {
      throw const FormatException('Bookmark limit reached');
    }
    await _write([...current, bookmark]);
  });
  Future<void> remove(RasterBookmark bookmark) =>
      database.transaction(() async {
        final current = await read();
        current.removeWhere(
          (v) =>
              v.revision == bookmark.revision &&
              v.page == bookmark.page &&
              v.fraction == bookmark.fraction,
        );
        await _write(current);
      });
  Future<void> _write(List<RasterBookmark> values) => database.customUpdate(
    'INSERT INTO app_preferences (key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload WHERE app_preferences.payload<>excluded.payload',
    variables: [
      Variable(key),
      Variable(jsonEncode(values.map((v) => v.toJson()).toList())),
    ],
    updates: {database.appPreferences},
  );
}
