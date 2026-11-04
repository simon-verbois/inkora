import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/saved_search_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/saved_catalogue_search.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_ahead_store.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';

import '../test/features/library/series_detail_widget_test.dart'
    show seedSeries;
import '../test/offline/progress_sync_test.dart' show FakeRemote;
import '../test/support/catalogue_fakes.dart';
import '../test/support/connection_fakes.dart';
import '../test/support/reader_fakes.dart';
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'automatic verified downloads and account-local saved searches with isolated native persistence',
    (tester) async {
      final root = await Directory.systemTemp.createTemp(
        'inkora-reading-ahead-',
      );
      final database = AppDatabase(
        NativeDatabase.createInBackground(File('${root.path}/test.sqlite')),
      );
      final account = savedSession.accountId;
      final store = DownloadStore(
        database,
        account,
        Directory('${root.path}/staging'),
      );
      final assets = ReaderAssetStore(
        database,
        Directory('${root.path}/cache'),
        Directory('${root.path}/downloads'),
      );
      final gate = PageNetworkGate();
      final progress = ProgressStore(database, account);
      final scheduler = DownloadScheduler(
        store,
        assets,
        gate,
        loadManifest: (book, _) async =>
            readerManifest(account: account, book: book, count: 1),
        transfer: (_, _, file, _, _) async {
          await file.writeAsBytes(fixtureRaster);
          return (mediaType: 'image/png', byteLength: fixtureRaster.length);
        },
        isCurrent: () => true,
      );
      final coordinator = OfflineCoordinator(
        store,
        assets,
        savedSession,
        scheduler,
        ProgressSync(progress, FakeRemote(), gate, isCurrent: () => true),
        BackgroundTransfer(),
        () => true,
      );
      UiHarness? harness;
      addTearDown(() async {
        coordinator.close();
        await coordinator.downloads.idle;
        await coordinator.sync.idle;
        await assets.idle;
        if (harness != null) {
          await harness.close(tester);
        } else {
          await database.close();
        }
        await root.delete(recursive: true);
        await SystemChrome.setPreferredOrientations([]);
      });
      final catalogue = CatalogueStore(database, account);
      await catalogue.stage('automatic', [
        for (var i = 1; i <= 4; i++) entry('b$i', number: i.toDouble()),
      ]);
      await catalogue.publish('automatic', DateTime.now(), () => true);
      await store.configure(quota: 256 * 1024 * 1024, wifiOnly: false);
      final ahead = DownloadAheadStore(database, account);
      await ahead.configure('series-a', 2);
      await coordinator.start();
      Future<void> completed(int count) async {
        for (var i = 0; i < 100; i++) {
          if ((await store.jobs())
                  .where((j) => j.state == DownloadState.complete)
                  .length ==
              count) {
            return;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        fail('Expected $count verified downloads');
      }

      await completed(2);
      expect(
        await assets.isDownloaded(
          readerManifest(account: account, book: 'b1', count: 1),
        ),
        isTrue,
      );
      await progress.observe(
        'b1',
        const ProgressSnapshot(
          revision: 'revision-a',
          pageIndex: 0,
          completed: true,
        ),
      );
      await completed(3);
      await ahead.configure('series-a', 0);
      coordinator.close();
      await scheduler.idle;
      harness = await UiHarness.create(
        tester,
        databaseOverride: database,
        refreshCatalogue: false,
        resumeEntries: const [],
        preferences: const UiPreferences(
          locale: 'fr',
          appearance: AppAppearance.light,
        ),
      );
      await seedSeries(harness, tester);
      await harness.mount(tester);
      await binding.convertFlutterSurfaceToImage();
      final router = harness.container.read(routerProvider);
      router.push<void>('/catalogue/series/series-a');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-download')));
      await tester.pumpAndSettle();
      final three = find.byKey(const Key('download-series-ahead-3'));
      await tester.ensureVisible(three);
      await tester.tap(three);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('download-ahead-fr');
      await tester.tap(find.byKey(const Key('ink-confirm-accept')));
      await tester.pumpAndSettle();
      expect(await ahead.count('series-a'), 3);
      final searches = SavedSearchStore(database, account);
      await searches.save(
        SavedCatalogueSearch(
          'Mystères en cours',
          CatalogueQuery(
            kind: CatalogueKind.series,
            readingUnits: true,
            filters: MetadataFilters.from({
              CatalogueFacet.genres: 'Mystery',
              CatalogueFacet.authors: 'Writer Name',
            }, readingStatus: ReadingStatus.inProgress),
            showUnavailable: false,
          ),
        ),
      );
      router.go('/catalogue/series');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalogue-saved-searches')));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('saved-searches-fr');
      await tester.tap(
        find.byKey(const ValueKey('saved-search-Mystères en cours')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moonlit District'), findsWidgets);
      await binding.takeScreenshot('saved-search-results-fr');
      expect(
        await SavedSearchStore(database, 'foreign').watch().first,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
