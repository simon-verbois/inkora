import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/resume_repository.dart';

void main() {
  final path = Platform.environment['INKORA_KOMGA_CREDENTIALS'];
  test(
    'live GET-only server shelf is available without local reading history',
    () async {
      final credentials =
          jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
      final client = KomgaClient(
        ServerEndpoint(credentials['url'] as String),
        Credentials.basic(
          credentials['username'] as String,
          credentials['password'] as String,
        ),
      );
      final database = AppDatabase(NativeDatabase.memory());
      final repository = ResumeRepository(
        CatalogueStore(database, 'live-fixture'),
        client,
        isCurrent: () => true,
      );
      addTearDown(() async {
        repository.close();
        client.close();
        await database.close();
      });
      await repository.refresh();
      final snapshot = await database
          .select(database.resumeSnapshots)
          .getSingle();
      final entries = await repository.watch().first;
      expect(
        (jsonDecode(snapshot.payload) as Map<String, dynamic>)['books'],
        hasLength(entries.where((entry) => !entry.onDeck).length),
      );
      expect(
        (jsonDecode(snapshot.payload) as Map<String, dynamic>)['onDeck'],
        hasLength(entries.where((entry) => entry.onDeck).length),
      );
      for (final entry in entries.where((entry) => entry.onDeck)) {
        expect(entry.progress, 0);
      }
      expect(entries.map((e) => e.item.id).toSet(), hasLength(entries.length));
      expect(await database.select(database.readerPositions).get(), isEmpty);
      expect(await database.select(database.progressEvents).get(), isEmpty);
    },
    skip: path == null
        ? 'Set INKORA_KOMGA_CREDENTIALS for authorized GET-only verification.'
        : false,
  );
}
