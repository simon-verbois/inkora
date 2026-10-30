import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../../reader/data/raster_bookmarks.dart';
import '../../../reader/domain/ebook_locator.dart';
import '../../../reader/domain/reading_settings.dart';
import '../domain/ui_preferences.dart';
import 'ui_preferences_store.dart';

/// No credentials, media files, progress, downloads or pending operations.
/// Files include account tuning and local bookmarks. All input is validated before a transaction can write.
final class SettingsTransfer {
  SettingsTransfer(this.database, this.account);
  final AppDatabase database;
  final String account;
  static const maxBytes = 4 * 1024 * 1024;

  Future<Uint8List> export() async {
    // Exact JSON-account prefixes keep other accounts' rows out of the worker.
    // Their final comma has the next lexical bound '-', so the primary-key
    // index can serve both ranges without LIKE wildcards or a table scan.
    final bookmarkPrefixes = [
      for (final kind in ['ebook', 'raster'])
        '$kind-bookmarks:[${jsonEncode(account)},',
    ];
    final data = await database.transaction(() async {
      final ui = await (database.select(
        database.appPreferences,
      )..where((r) => r.key.equals('ui'))).getSingleOrNull();
      final preferences =
          await (database.select(database.readingPreferences)..where(
                (r) =>
                    r.accountId.equals(account) &
                    r.scope.isIn(SettingsScope.values.map((s) => s.name)),
              ))
              .get();
      final bookmarks = await database
          .customSelect(
            'SELECT key,payload FROM app_preferences WHERE (key>=? AND key<?) OR (key>=? AND key<?)',
            variables: [
              for (final prefix in bookmarkPrefixes) ...[
                Variable(prefix),
                Variable('${prefix.substring(0, prefix.length - 1)}-'),
              ],
            ],
          )
          .get()
          .then(
            (rows) => rows
                .map(
                  (r) => AppPreference(
                    key: r.read<String>('key'),
                    payload: r.read<String>('payload'),
                  ),
                )
                .toList(),
          );
      return {
        'ui': ui?.payload,
        'preferences': [
          for (final p in preferences)
            {'scope': p.scope, 'id': p.scopeId, 'payload': p.payload},
        ],
        'bookmarks': [
          for (final b in bookmarks) {'key': b.key, 'payload': b.payload},
        ],
      };
    });
    return _exportWorker(data, account);
  }

  Future<Map<String, dynamic>> inspect(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds size limit');
    }
    return Isolate.run(() => validate(jsonDecode(utf8.decode(bytes))));
  }

  static Map<String, dynamic> validate(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['format'] != 'inkora-settings' ||
        raw['version'] != 1 ||
        raw['portable'] is! bool) {
      throw const FormatException('Invalid backup format or version');
    }
    final portable = raw['portable'] as bool;
    if (!portable &&
        (raw['account'] is! String ||
            (raw['account'] as String).length > 4096)) {
      throw const FormatException('Missing backup account');
    }
    if (raw['ui'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid UI preferences');
    }
    final ui =
        UiPreferences.fromJson(raw['ui'] as Map<String, dynamic>).toJson()
          ..remove('setupCompleted')
          ..remove('setupStep')
          ..remove('setupVersion');
    final prefs = raw['preferences'];
    final bookmarks = raw['bookmarks'];
    if (prefs is! List ||
        prefs.length > 20000 ||
        bookmarks is! List ||
        bookmarks.length > 10000 ||
        portable && bookmarks.isNotEmpty) {
      throw const FormatException('Invalid backup entries');
    }
    final identities = <String>{};
    final normalized = <Object>[];
    for (final p in prefs) {
      if (p is! Map ||
          p['scope'] is! String ||
          p['id'] is! String ||
          (p['id'] as String).length > 1024 ||
          p['value'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid reading preferences');
      }
      final scope = SettingsScope.values.byName(p['scope'] as String);
      if ((scope == SettingsScope.global) != (p['id'] == '') ||
          portable && scope != SettingsScope.global ||
          !identities.add('${scope.name}:${p['id']}')) {
        throw const FormatException('Invalid preference scope');
      }
      final value = ReadingOverrides.fromJson(
        p['value'] as Map<String, dynamic>,
      );
      ReadingSettings.resolve([value]);
      if (scope != SettingsScope.book && value.libraryDefaults) {
        throw const FormatException('Invalid library binding');
      }
      normalized.add({
        'scope': scope.name,
        'id': p['id'],
        'value': value.toJson(),
      });
    }
    final bookmarkIds = <String>{};
    for (final b in bookmarks) {
      if (b is! Map ||
          !{'ebook', 'raster'}.contains(b['kind']) ||
          b['book'] is! String ||
          (b['book'] as String).isEmpty ||
          (b['book'] as String).length > 1024 ||
          b['values'] is! List ||
          (b['values'] as List).length > 200 ||
          !bookmarkIds.add('${b['kind']}:${b['book']}')) {
        throw const FormatException('Invalid bookmarks');
      }
      for (final v in b['values'] as List) {
        if (v is! Map<String, dynamic>) {
          throw const FormatException('Invalid bookmark');
        }
        if (b['kind'] == 'raster') {
          RasterBookmark.fromJson(v);
        } else {
          EbookLocator(v);
        }
      }
    }
    return {
      'format': 'inkora-settings',
      'version': 1,
      'portable': portable,
      if (!portable) 'account': raw['account'],
      'ui': ui,
      'preferences': normalized,
      'bookmarks': bookmarks,
    };
  }

  Future<void> apply(Map<String, dynamic> preview) async {
    // Revalidate; callers cannot bypass inspection by constructing a map.
    final checked = await _validateWorker(preview);
    if (checked['portable'] != true && checked['account'] != account) {
      throw const FormatException(
        'This backup belongs to another server or account.',
      );
    }
    await database.transaction(() async {
      final current = await UiPreferencesStore(database).watch().first;
      await UiPreferencesStore(database).save(
        UiPreferences.fromJson({
          ...checked['ui'] as Map<String, dynamic>,
          'setupCompleted': current.setupCompleted,
          'setupStep': current.setupStep,
          'setupVersion': 3,
        }),
      );
      for (final p in checked['preferences'] as List) {
        await database.customUpdate(
          'INSERT INTO reading_preferences(account_id,scope,scope_id,payload) VALUES (?,?,?,?) ON CONFLICT(account_id,scope,scope_id) DO UPDATE SET payload=excluded.payload WHERE reading_preferences.payload<>excluded.payload',
          variables: [
            Variable(account),
            Variable(p['scope'] as String),
            Variable(p['id'] as String),
            Variable(jsonEncode(p['value'])),
          ],
          updates: {database.readingPreferences},
        );
      }
      for (final b in checked['bookmarks'] as List) {
        final key =
            '${b['kind']}-bookmarks:${jsonEncode([account, b['book']])}';
        final existing = await database
            .customSelect(
              'SELECT payload FROM app_preferences WHERE key=?',
              variables: [Variable(key)],
            )
            .getSingleOrNull();
        final previous = existing?.read<String>('payload');
        final payload = await _mergeWorker(
          previous,
          Map<String, dynamic>.from(b as Map),
        );
        await database.customUpdate(
          'INSERT INTO app_preferences(key,payload) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload WHERE app_preferences.payload<>excluded.payload',
          variables: [Variable(key), Variable(payload)],
          updates: {database.appPreferences},
        );
      }
    });
  }
}

Future<Uint8List> _exportWorker(Map<String, Object?> data, String accountId) =>
    Isolate.run(() {
      final ui =
          UiPreferences.fromJson(
              data['ui'] == null
                  ? {}
                  : jsonDecode(data['ui'] as String) as Map<String, dynamic>,
            ).toJson()
            ..remove('setupCompleted')
            ..remove('setupStep')
            ..remove('setupVersion');
      final result = <String, dynamic>{
        'format': 'inkora-settings',
        'version': 1,
        'portable': false,
        'account': accountId,
        'ui': ui,
        'preferences': [
          for (final p in data['preferences'] as List)
            {
              'scope': p['scope'],
              'id': p['id'],
              'value': jsonDecode(p['payload'] as String),
            },
        ],
        'bookmarks': <Object>[],
      };
      for (final b in data['bookmarks'] as List) {
        final key = b['key'] as String;
        final raster = key.startsWith('raster-');
        final identity = jsonDecode(key.substring(raster ? 17 : 16)) as List;
        if (identity.length == 2 && identity[0] == accountId) {
          (result['bookmarks'] as List).add({
            'kind': raster ? 'raster' : 'ebook',
            'book': identity[1],
            'values': jsonDecode(b['payload'] as String),
          });
        }
      }
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(result)));
      if (bytes.length > SettingsTransfer.maxBytes) {
        throw const FormatException('Backup exceeds size limit');
      }
      return bytes;
    });

Future<String> _mergeWorker(String? previous, Map<String, dynamic> b) =>
    Isolate.run(() {
      final values = <String, dynamic>{};
      String identity(dynamic v) => b['kind'] == 'ebook'
          ? EbookLocator(Map<String, dynamic>.from(v as Map)).bookmarkKey
          : '${v['revision']}:${v['page']}:${v['fraction']}';
      for (final v in previous == null ? [] : jsonDecode(previous) as List) {
        values[identity(v)] = v;
      }
      for (final v in b['values'] as List) {
        values[identity(v)] = v;
      }
      if (values.length > 200) {
        throw const FormatException('Bookmark limit reached');
      }
      return jsonEncode(values.values.toList());
    });

Future<Map<String, dynamic>> _validateWorker(Map<String, dynamic> preview) =>
    Isolate.run(() => SettingsTransfer.validate(preview));
