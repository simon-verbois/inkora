import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_filters.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../test/offline/progress_sync_test.dart' show FakeRemote;
import '../test/support/catalogue_artwork.dart';
import '../test/support/connection_fakes.dart';
import '../test/support/reader_widget_support.dart';
import '../test/support/ui_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture the requested UI fixes on native Android', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final root = await Directory.systemTemp.createTemp('inkora-ui-captures-');
    final artwork = <String, Uint8List>{};
    for (var i = 0; i < demonstrationTitles.length; i++) {
      artwork[i == 0 ? 'series-a' : 'demo-series-$i'] =
          await demonstrationCover(i);
    }
    final client = fixtureClient(
      savedSession.endpoint,
      savedSession.credentials,
      FixtureAdapter((request) {
        final id = request.uri.pathSegments.reversed.skip(1).first;
        return ResponseBody.fromBytes(
          artwork[id] ?? artwork['series-a']!,
          200,
          headers: {
            'content-type': ['image/png'],
          },
        );
      }),
    );
    final covers = CoverRepository(
      client,
      PageNetworkGate(),
      Directory('${root.path}/covers'),
      savedSession.accountId,
    );
    final volumes = [
      for (var n = 1; n <= 12; n++)
        CatalogueItem(
          kind: CatalogueKind.book,
          id: 'v$n',
          seriesId: 'series-a',
          libraryId: 'library-a',
          title: 'Moonlit District — Tome $n',
          number: n.toDouble(),
          pageCount: 192,
          readingStatus: n < 3
              ? ReadingStatus.completed
              : n == 3
              ? ReadingStatus.inProgress
              : ReadingStatus.unread,
          readPage: n == 3
              ? 68
              : n < 3
              ? 191
              : null,
        ),
    ];
    OfflineCoordinator? offline;
    final harness = await UiHarness.create(
      tester,
      covers: covers,
      preferences: const UiPreferences(
        locale: 'fr',
        appearance: AppAppearance.ocean,
      ),
      resumeEntries: [
        ResumeEntry(
          item: volumes[2],
          seriesTitle: demonstrationTitles.first,
          pageIndex: 68,
          pageCount: 192,
          fraction: 0,
        ),
      ],
      catalogue: [
        const CatalogueItem(
          kind: CatalogueKind.library,
          id: 'library-a',
          title: 'Bibliothèque Manga',
        ),
        for (var i = 0; i < demonstrationTitles.length; i++)
          CatalogueItem(
            kind: CatalogueKind.series,
            id: i == 0 ? 'series-a' : 'demo-series-$i',
            title: demonstrationTitles[i],
            libraryId: 'library-a',
            itemCount: i == 0 ? 12 : 4 + i,
            summary: i == 0
                ? 'Dans les ruelles d’une ville où la nuit semble ne jamais finir, une jeune enquêtrice suit la trace de lanternes mystérieuses. Chaque lumière révèle une histoire oubliée et rapproche les habitants d’un secret enfoui depuis des générations. Entre les quais silencieux, les jardins suspendus et les archives de la vieille ville, elle devra choisir à qui faire confiance. Une aventure pleine de rencontres, de mystère et de poésie, au cœur d’un quartier qui ne dort jamais.'
                : '',
            metadata: const CatalogueMetadata(
              status: 'ONGOING',
              genres: ['Mystère', 'Aventure'],
              tags: ['score: 8.4'],
              authors: [CatalogueAuthor('Camille Laurent', 'writer')],
            ),
          ),
        ...volumes,
        const CatalogueItem(
          kind: CatalogueKind.book,
          id: 'novel',
          libraryId: 'library-a',
          title: 'The Lantern Keeper',
          summary: 'An illustrated journey through the quiet streets and secret libraries of the old city.',
          metadata: CatalogueMetadata(
            mediaType: 'application/epub+zip',
            authors: [CatalogueAuthor('Camille Laurent', 'writer')],
            tags: ['score: 8.4'],
            publisher: 'Fixture Press',
          ),
        ),
      ],
      offlineFactory: (database) {
        final store = DownloadStore(
          database,
          savedSession.accountId,
          Directory('${root.path}/staging'),
        );
        final assets = ReaderAssetStore(
          database,
          Directory('${root.path}/cache'),
          Directory('${root.path}/downloads'),
        );
        final gate = PageNetworkGate();
        return offline = OfflineCoordinator(
          store,
          assets,
          savedSession,
          DownloadScheduler(
            store,
            assets,
            gate,
            loadManifest: (_, _) =>
                throw StateError('Capture fixture has no remote downloads'),
            transfer: (_, _, _, _, _) => throw StateError('No transfer'),
            isCurrent: () => true,
          ),
          ProgressSync(
            ProgressStore(database, savedSession.accountId),
            FakeRemote(),
            gate,
            isCurrent: () => true,
          ),
          BackgroundTransfer(),
          () => true,
        );
      },
    );
    addTearDown(() async {
      await harness.close(tester);
      offline?.close();
      await covers.flush();
      covers.close();
      client.close();
      await root.delete(recursive: true);
      await SystemChrome.setPreferredOrientations([]);
    });
    await tester.runAsync(() async {
      for (final book in [volumes[0], volumes[3]]) {
        final manifest = ReaderManifest(
          accountId: savedSession.accountId,
          bookId: book.id,
          revision: 'capture',
          title: book.title,
          seriesId: 'series-a',
          libraryId: 'library-a',
          pages: List.generate(
            192,
            (_) => PageDimensions(480, 690, sizeBytes: 1024),
          ),
        );
        await offline!.store.state(
          await offline!.store.enqueue(manifest),
          DownloadState.complete,
        );
      }
    });
    await harness.mount(tester);
    await binding.convertFlutterSurfaceToImage();
    final router = harness.container.read(routerProvider);
    Future<void> capture(String name) async {
      await settleReaderImages(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await capture('01-home-initial');
    if (find.byKey(const Key('catalogue-tools-menu')).evaluate().isNotEmpty) {
      await tap('catalogue-tools-menu');
      await capture('02a-catalogue-tools-menu');
      await tap('catalogue-library-menu');
    } else {
      await tap('library-selector');
    }
    await capture('02-library-menu');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    router.push<void>('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    await capture('03-series-description');
    await tap('detail-download');
    await capture('04-download-entire-series');
    await tap('download-series-unread');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await capture('05-download-unread-retention');
    await tap('ink-confirm-cancel');
    await tap('detail-mark');
    await capture('06-reading-progress-dialog');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    if (find.byKey(const Key('series-tab-volumes')).evaluate().isNotEmpty) {
      await tap('series-tab-volumes');
    }
    await capture('07-volumes-initial');
    await tap('volume-mark-read-v3');
    await capture('08-mark-read-confirmation');
    await tap('ink-confirm-cancel');
    router.go('/downloads');
    await tester.pumpAndSettle();
    await capture('09-downloads-initial');
    router.go('/catalogue/book/novel');
    await tester.pumpAndSettle();
    await capture('09a-ebook-details-initial');
    router.go('/');
    await tester.pumpAndSettle();
    await harness.mount(tester, textScale: 1.5);
    await tester.pumpAndSettle();
    if (find.byKey(const Key('home-menu')).evaluate().isNotEmpty) {
      await tap('home-menu');
      await capture('10-home-overflow-menu');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    } else {
      await capture('10-home-large-text-header');
    }
    await harness.mount(tester);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.view.physicalSize.width > tester.view.physicalSize.height) {
        break;
      }
    }
    expect(
      tester.view.physicalSize.width,
      greaterThan(tester.view.physicalSize.height),
    );
    router.go('/catalogue/series/series-a');
    await tester.pumpAndSettle();
    if (find.byKey(const Key('series-tab-volumes')).evaluate().isNotEmpty) {
      await tap('series-tab-volumes');
    }
    await capture('11-volumes-landscape');
    await tap('detail-download');
    await capture('12-download-dialog-landscape');
    await tap('ink-confirm-cancel');
    router.go('/');
    await tester.pumpAndSettle();
    await capture('13-home-landscape');
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await capture('14-home-scroll-overlap');
    router.go('/catalogue/book/novel');
    await tester.pumpAndSettle();
    await capture('15-ebook-details-landscape');
    await harness.close(tester);
  });
}
