import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

void main() {
  test('v8 cleanup removes only favorites and preserves both accounts after reopen', () async {
    final folder = await Directory.systemTemp.createTemp('inkora-v8-cleanup-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/database.sqlite');
    final previous = AppDatabase(NativeDatabase(file));
    try {
      for (final account in ['account-a', 'account-b']) {
        final catalogue = CatalogueStore(previous, account);
        await catalogue.stage('saved', [
          const CatalogueItem(
            kind: CatalogueKind.series,
            id: 'series',
            title: 'Saved series',
          ),
        ]);
        await catalogue.publish('saved', DateTime.utc(2026), () => true);
        await previous.customStatement(
          'INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES (?, ?, ?, ?, ?)',
          [account, 'book', 'revision', 3, .5],
        );
        await previous.customStatement(
          'INSERT INTO reading_preferences VALUES (?, ?, ?, ?)',
          [account, 'library', 'library-a', '{}'],
        );
        await previous.customStatement(
          'INSERT INTO reader_downloads VALUES (?, ?, ?)',
          [account, 'book', 'revision'],
        );
        await previous.customStatement(
          'INSERT INTO progress_events (account_id,book_id,sequence,revision,page_index,fraction,operation,state,page_count) VALUES (?, ?, 1, ?, 3, 0.5, ?, ?, 10)',
          [account, 'book', 'revision', 'advance', 'queued'],
        );
        await previous.customStatement(
          'INSERT INTO app_preferences VALUES (?, ?)',
          ['favorites-sync:$account', 'true'],
        );
      }
      await previous.customStatement(
        "INSERT INTO app_preferences VALUES ('ui', '{\"appearance\":\"dark\"}')",
      );
      await previous.customStatement(
        "INSERT INTO app_preferences VALUES ('discovery:account-a', '{\"sections\":[]}')",
      );
      await previous.customStatement(
        "INSERT INTO app_preferences VALUES ('otherapp.favorites-sync:key', 'preserved')",
      );
      await previous.customStatement(
        'CREATE TABLE favorite_series (account_id TEXT NOT NULL, series_id TEXT NOT NULL, active INTEGER NOT NULL, pending INTEGER NOT NULL, revision INTEGER NOT NULL, PRIMARY KEY (account_id, series_id))',
      );
      await previous.customStatement(
        "INSERT INTO favorite_series VALUES ('account-a', 'series', 1, 1, 2)",
      );
      await previous.customStatement(
        "INSERT INTO favorite_series VALUES ('account-b', 'series', 0, 1, 3)",
      );
      await previous.customStatement('PRAGMA user_version=8');
    } finally {
      await previous.close();
    }
    for (var open = 0; open < 2; open++) {
      final database = AppDatabase(NativeDatabase(file));
      try {
        final version = await database
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 11);
        final legacy = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='favorite_series'",
            )
            .get();
        expect(legacy, isEmpty);
        final preferences = await database
            .select(database.appPreferences)
            .get();
        expect(preferences.map((row) => row.key).toSet(), {
          'ui',
          'discovery:account-a',
          'otherapp.favorites-sync:key',
        });
        expect(
          preferences.singleWhere((row) => row.key == 'ui').payload,
          '{"appearance":"dark"}',
        );
        for (final account in ['account-a', 'account-b']) {
          expect(
            (await CatalogueStore(database, account).read(
              const CatalogueQuery(kind: CatalogueKind.series),
            )).items.single.title,
            'Saved series',
          );
        }
        expect(
          (await database.select(database.readerPositions).get()).map(
            (row) => row.pageIndex,
          ),
          [3, 3],
        );
        expect(
          await database.select(database.readingPreferences).get(),
          hasLength(2),
        );
        expect(
          await database.select(database.readerDownloads).get(),
          hasLength(2),
        );
        expect(
          (await database.select(database.progressEvents).get()).every(
            (row) => row.state == 'queued',
          ),
          true,
        );
      } finally {
        await database.close();
      }
    }
  });
}
