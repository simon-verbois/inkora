import 'package:drift/native.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/komga_catalogue_remote.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/domain/session.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

void main() {
  final credentialsFile = Platform.environment['INKORA_KOMGA_CREDENTIALS'];
  test(
    'live raster reader fetches page bytes then reopens cached pages without network',
    () async {
      final json = jsonDecode(
        File(credentialsFile!).readAsStringSync(),
      ) as Map<String, dynamic>;
      final credentials = Credentials.basic(
        json['username'] as String,
        json['password'] as String,
      );
      final client = KomgaClient(
        ServerEndpoint(json['url'] as String),
        credentials,
      );
      final user = await client.currentUser();
      final account = SavedSession(
        endpoint: client.endpoint,
        user: user,
        credentials: credentials,
      ).accountId;
      final database = AppDatabase(NativeDatabase.memory());
      final folder = await Directory.systemTemp.createTemp(
        'inkora-live-reader-',
      );
      final assets = ReaderAssetStore(
        database,
        Directory('${folder.path}/cache'),
        Directory('${folder.path}/download'),
      );
      final repository = ReaderRepository(
        ReaderStore(database, account),
        assets,
        client,
        PageNetworkGate(),
        isCurrent: () => true,
      );
      try {
        final books = await client.books(size: 2);
        final opened = await repository.open(books.items.first.id);
        final page = await opened.source.read(
          opened.manifest.key(0),
          cancellation: CancellationController(),
        );
        expect(page.bytes, isNotEmpty);
        expect(page.mediaType, startsWith('image/'));
        await repository.store.saveLocator(
          opened.manifest,
          ReaderLocator(0, .25),
        );
        repository.release(opened);
        client.close();
        final offline = await repository.open(books.items.first.id);
        final saved = await offline.source.read(
          offline.manifest.key(0),
          cancellation: CancellationController(),
        );
        expect(saved.bytes, page.bytes);
        expect(offline.locator.fraction, .25);
      } finally {
        repository.close();
        client.close();
        await assets.idle;
        await database.close();
        await folder.delete(recursive: true);
      }
    },
    skip: credentialsFile == null
        ? 'Set INKORA_KOMGA_CREDENTIALS for explicit live reader verification.'
        : false,
  );
  test(
    'live HTTPS server authenticates and supplies negotiated paginated books',
    () async {
      final json = jsonDecode(
        File(credentialsFile!).readAsStringSync(),
      ) as Map<String, dynamic>;
      final client = KomgaClient(
        ServerEndpoint(json['url'] as String),
        Credentials.basic(
          json['username'] as String,
          json['password'] as String,
        ),
      );
      addTearDown(client.close);
      final user = await client.currentUser();
      expect(user.id, isNotEmpty);
      final capabilities = await client.negotiateCapabilities(user);
      expect(capabilities.version, '1.28.1');
      expect(capabilities.schemaAvailable, isTrue);
      final first = await client.books(size: 2);
      final second = await client.books(page: 1, size: 2);
      expect(first.number, 0);
      expect(second.number, 1);
      expect(first.items, hasLength(2));
      final pages = await client.pages(first.items.first.id);
      expect(pages.length, first.items.first.pageCount);
      expect(pages.first.index, 0);
    },
    skip: credentialsFile == null
        ? 'Set INKORA_KOMGA_CREDENTIALS to an ignored credentials JSON file.'
        : false,
  );
  test(
    'live full catalogue refresh publishes a searchable offline snapshot',
    () async {
      final json = jsonDecode(
        File(credentialsFile!).readAsStringSync(),
      ) as Map<String, dynamic>;
      final client = KomgaClient(
        ServerEndpoint(json['url'] as String),
        Credentials.basic(
          json['username'] as String,
          json['password'] as String,
        ),
      );
      final user = await client.currentUser();
      final database = AppDatabase(NativeDatabase.memory());
      final store = CatalogueStore(
        database,
        SavedSession(
          endpoint: client.endpoint,
          user: user,
          credentials: Credentials.apiKey('unused-fixture'),
        ).accountId,
      );
      final repository = CatalogueRepository(
        store,
        KomgaCatalogueRemote(client),
      );
      addTearDown(() async {
        repository.close();
        client.close();
        await database.close();
      });
      await repository.refresh();
      expect(await store.snapshot(), isNotNull);
      final books = await store.read(
        const CatalogueQuery(kind: CatalogueKind.book),
      );
      final series = await store.read(
        const CatalogueQuery(kind: CatalogueKind.series),
      );
      final libraries = await store.read(
        const CatalogueQuery(kind: CatalogueKind.library),
      );
      expect(books.total, greaterThan(0));
      expect(series.total, greaterThan(0));
      expect(libraries.total, greaterThan(0));
      client.close();
      final offline = await store.read(
        CatalogueQuery(
          kind: CatalogueKind.book,
          search: books.items.first.title,
        ),
      );
      expect(offline.total, greaterThan(0));
    },
    skip: credentialsFile == null
        ? 'Set INKORA_KOMGA_CREDENTIALS for explicit live verification.'
        : false,
  );
}
