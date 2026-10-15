import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';

import '../../support/catalogue_fakes.dart';

void main() {
  test(
    'v6 recovery retains an already added metadata column and reading data',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'inkora-partial-v7-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/database.sqlite');
      final previous = AppDatabase(NativeDatabase(file));
      final store = CatalogueStore(previous, 'account');
      await store.stage('published', [
        const CatalogueItem(
          kind: CatalogueKind.series,
          id: 'series',
          title: 'Saved series',
          metadata: CatalogueMetadata(publisher: 'Saved publisher'),
        ),
      ]);
      await store.publish('published', DateTime.utc(2026, 10, 12), () => true);
      await previous.customStatement(
        "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('account', 'book', 'revision', 2, 0.5)",
      );
      await previous.customStatement('PRAGMA user_version=6');
      await previous.close();
      final recovered = AppDatabase(NativeDatabase(file));
      try {
        final item = await CatalogueStore(
          recovered,
          'account',
        ).item(CatalogueKind.series, 'series').first;
        expect(item!.metadata.publisher, 'Saved publisher');
        expect(
          (await recovered.select(recovered.readerPositions).getSingle())
              .fraction,
          .5,
        );
        final version = await recovered
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 10);
      } finally {
        await recovered.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await CatalogueStore(
            reopened,
            'account',
          ).item(CatalogueKind.series, 'series').first)!.metadata.publisher,
          'Saved publisher',
        );
      } finally {
        await reopened.close();
      }
    },
  );
  test('v5 upgrade preserves preferences, pending progress and downloaded metadata', () async {
    final folder = await Directory.systemTemp.createTemp('inkora-v5-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/database.sqlite');
    final previous = AppDatabase(NativeDatabase(file));
    await previous.customStatement(
      "INSERT INTO app_preferences VALUES ('appearance', 'light')",
    );
    await previous.customStatement(
      "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('account', 'book', 'revision', 2, 0.5)",
    );
    await previous.customStatement(
      "INSERT INTO progress_events (account_id,book_id,sequence,revision,page_index,fraction,operation,state,page_count) VALUES ('account','book',1,'revision',2,0.5,'advance','queued',10)",
    );
    await previous.customStatement(
      "INSERT INTO download_jobs (id,account_id,book_id,revision,manifest,state,reserved_bytes) VALUES ('job','account','book','revision','{}','complete',100)",
    );
    await previous.customStatement('DROP TABLE resume_snapshots');
    await previous.customStatement('DROP INDEX catalogue_document_books');
    await previous.customStatement(
      'ALTER TABLE catalogue_entries DROP COLUMN descriptive_metadata',
    );
    await previous.customStatement('PRAGMA user_version=5');
    await previous.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    try {
      expect(await upgraded.select(upgraded.resumeSnapshots).get(), isEmpty);
      expect(
        (await upgraded.select(upgraded.readerPositions).getSingle()).fraction,
        .5,
      );
      expect(
        (await upgraded.select(upgraded.progressEvents).getSingle()).operation,
        'advance',
      );
      expect(
        (await upgraded.select(upgraded.downloadJobs).getSingle()).state,
        'complete',
      );
      expect(
        (await upgraded.select(upgraded.appPreferences).getSingle()).payload,
        'light',
      );
    } finally {
      await upgraded.close();
    }
  });
  test('v1 database upgrades to the current schema with profiles and catalogue preserved', () async {
    final folder = await Directory.systemTemp.createTemp('inkora-migration-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/database.sqlite');
    final database = AppDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute(
            'CREATE TABLE server_profiles (id TEXT NOT NULL PRIMARY KEY, display_name TEXT NOT NULL, base_url TEXT NOT NULL)',
          );
          db.execute(
            "INSERT INTO server_profiles VALUES ('existing', 'Personal', 'https://example.test/')",
          );
          db.execute('PRAGMA user_version=1');
        },
      ),
    );
    expect(
      (await database.select(database.serverProfiles).getSingle()).id,
      'existing',
    );
    expect(database.schemaVersion, 10);
    final store = CatalogueStore(database, 'account');
    await store.stage('durable', [entry('book')]);
    await store.publish('durable', DateTime.utc(2026, 10, 11), () => true);
    await database.close();
    final reopened = AppDatabase(NativeDatabase(file));
    try {
      expect(
        (await reopened.select(reopened.serverProfiles).getSingle()).id,
        'existing',
      );
      expect(
        (await CatalogueStore(
          reopened,
          'account',
        ).read(const CatalogueQuery(kind: CatalogueKind.book))).items.single.id,
        'book',
      );
    } finally {
      await reopened.close();
    }
  });
}
