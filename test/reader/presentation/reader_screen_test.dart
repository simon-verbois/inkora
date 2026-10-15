import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/data/tiered_page_source.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

void main() {
  testWidgets(
    'opening failure is visible immediately and retry opens the reader',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final directory = Directory.systemTemp.createTempSync('inkora-screen-');
      final book =
          (jsonDecode(
                        File(
                          'test/fixtures/komga/1.28.1/catalogue/local-book-0.json',
                        ).readAsStringSync(),
                      )['content']
                      as List)
                  .first
              as Map<String, dynamic>;
      (book['media'] as Map)['mediaProfile'] = 'EPUB';
      final adapter = FixtureAdapter((_) => jsonResponse(book));
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        adapter,
      );
      final repository = ReaderRepository(
        ReaderStore(database, savedSession.accountId),
        ReaderAssetStore(
          database,
          Directory('${directory.path}/cache'),
          Directory('${directory.path}/downloads'),
        ),
        client,
        PageNetworkGate(),
        isCurrent: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          readerRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ReaderScreen(bookId: book['id'] as String)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        find.text('This book has no supported raster pages.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(adapter.requests.length, 1);
      final manifest = readerManifest(
        account: savedSession.accountId,
        book: book['id'] as String,
        count: 1,
      );
      await tester.runAsync(() => repository.store.saveManifest(manifest));
      // Retry uses a saved manifest without issuing a second metadata request.
      await tester.tap(find.text('Retry'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      await tester.tapAt(
        Offset(20, tester.getCenter(find.byType(ReaderScreen)).dy),
      );
      await settleReaderImages(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(
        find.text('This book has no supported raster pages.'),
        findsNothing,
      );
      // The image request is deliberately invalid; it must remain a page-level error.
      expect(find.text('Retry page'), findsOneWidget);
      await tester.runAsync(database.close);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      repository.close();
      client.close();
      await tester.runAsync(() => directory.delete(recursive: true));
      expect(tester.takeException(), isNull);
    },
  );
}
