import 'package:inkora/app/icons/inkora_icons.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/features/library/presentation/volume_actions.dart';
import 'package:inkora/features/library/presentation/volume_list_tile.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/widgets/ink_filter_bar.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_scheduler.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/data/download_retention_store.dart';
import 'package:inkora/offline/data/progress_store.dart';
import 'package:inkora/offline/data/progress_sync.dart';
import 'package:inkora/offline/domain/progress.dart';
import 'package:inkora/offline/presentation/downloads_screen.dart';
import 'package:inkora/offline/presentation/download_settings_panel.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/offline/presentation/progress_sheet.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/page_source.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';

import '../support/reader_widget_support.dart';
import '../support/catalogue_fakes.dart';

import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../support/connection_fakes.dart';
import '../support/reader_fakes.dart';
import 'progress_sync_test.dart' show FakeRemote;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase database;
  late OfflineCoordinator service;
  late ProviderContainer container;
  final openBooks = <String>{};
  setUp(() async {
    openBooks.clear();
    root = await Directory.systemTemp.createTemp('inkora-offline-ui-');
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    final assets = ReaderAssetStore(
      database,
      Directory('${root.path}/cache'),
      Directory('${root.path}/downloads'),
    );
    final store = DownloadStore(
      database,
      'reader-account',
      Directory('${root.path}/stage'),
    );
    final gate = PageNetworkGate();
    service = OfflineCoordinator(
      store,
      assets,
      savedSession,
      DownloadScheduler(
        store,
        assets,
        gate,
        loadManifest: (book, _) async => readerManifest(book: book),
        transfer: (_, _, _, _, _) => throw StateError('No implicit transfers'),
        isCurrent: () => true,
      ),
      ProgressSync(
        ProgressStore(database, 'reader-account'),
        FakeRemote(),
        gate,
        isCurrent: () => true,
      ),
      BackgroundTransfer(),
      () => true,
      bookInUse: openBooks.contains,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          BackgroundTransfer.channel,
          (call) async => call.method == 'results' ? [] : null,
        );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(Future.value(database)),
        coverRepositoryProvider.overrideWith((ref) async => null),
        offlineCoordinatorProvider.overrideWith((ref) async => service),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    service.close();
    await service.downloads.idle;
    await service.sync.idle;
    await service.assets.idle;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundTransfer.channel, null);
    await database.close();
    await root.delete(recursive: true);
  });
  Future<void> settle(WidgetTester tester) async {
    for (var turn = 0; turn < 6; turn++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.runAsync(() async {
      await tester.tap(target);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await settle(tester);
  }

  testWidgets('series confirmation cannot enqueue into a different account', (
    tester,
  ) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await expectLater(
        queueVolumeDownloads(captured, [
          'reader-book',
        ], accountId: 'previous-account'),
        throwsStateError,
      );
      expect(await service.store.jobs(), isEmpty);
    });
  });

  testWidgets(
    'retention defers an open book at launch and removes it on a later resume without changing progress',
    (tester) async {
      final manifest = readerManifest();
      final retention = DownloadRetentionStore(database, manifest.accountId);
      late String id;
      await tester.runAsync(() async {
        id = await service.store.enqueue(manifest);
        await service.store.state(id, DownloadState.complete);
        await service.sync.store.observe(
          manifest.bookId,
          ProgressSnapshot(revision: manifest.revision, completed: true),
        );
        await retention.readingStateChanged(
          manifest.bookId,
          now: DateTime.now().subtract(const Duration(days: 2)),
        );
        await retention.configure('series', true);
        openBooks.add(manifest.bookId);
        await service.start();
        expect(await service.store.stateOf(id), DownloadState.complete);
      });
      openBooks.clear();
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settle(tester);
      await tester.runAsync(() async {
        expect(await service.store.stateOf(id), DownloadState.cancelled);
        final head = await database
            .customSelect('SELECT baseline FROM progress_heads')
            .getSingle();
        expect(
          ProgressSnapshot.decode(head.read<String>('baseline')).completed,
          isTrue,
        );
      });
    },
  );

  testWidgets(
    'background engine startup preserves native ownership until resume',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(BackgroundTransfer.channel, (call) async {
            calls.add(call.method);
            return call.method == 'results' ? [] : null;
          });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      try {
        await tester.runAsync(service.start);
        expect(calls, isEmpty);
        await tester.runAsync(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await settle(tester);
        expect(
          calls,
          containsAllInOrder([
            'foreground',
            'results',
            'cancelAccount',
            'excludeFromBackup',
          ]),
        );
      } finally {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    },
  );

  testWidgets(
    'download settings show storage and network without a transfer queue',
    (tester) async {
      final id = (await tester.runAsync(
        () => service.store.enqueue(readerManifest()),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: DownloadSettingsPanel()),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Fixture reader'), findsNothing);
      expect(find.text('Browse libraries'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('No downloads in the queue'), findsNothing);
      expect(find.text('Storage and network'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DownloadSettingsPanel),
          matching: find.byType(InkSurface),
        ),
        findsNothing,
      );
      expect(find.text('Download storage quota'), findsOneWidget);
      final previous = service.store.wifiOnly;
      await tap(tester, find.byType(SwitchListTile));
      await settle(tester);
      expect(service.store.wifiOnly, !previous);
      expect(
        (await tester.runAsync(() => service.store.job(id)))!.state,
        isNot(DownloadState.cancelled),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'inline transfers retain pause and cancel on the Downloads shelf',
    (tester) async {
      final id = (await tester.runAsync(
        () => service.store.enqueue(readerManifest()),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DownloadsScreen()),
        ),
      );
      await settle(tester);
      // The queue card appears only with unfinished work; its status uses the
      // unified labels and the pending hourglass, not the history clock.
      expect(find.byKey(const Key('download-queue')), findsOneWidget);
      expect(find.text('Fixture reader'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(find.byIcon(InkIcons.hourglassMedium), findsOneWidget);
      expect(find.byIcon(InkIcons.clockCounterClockwise), findsNothing);
      expect(find.byType(InkProgressRing), findsOneWidget);
      expect(find.byKey(const Key('download-storage')), findsNothing);
      expect(find.text('Download storage quota'), findsNothing);
      await tap(tester, find.byTooltip('Pause'));
      await settle(tester);
      expect(
        (await tester.runAsync(() => service.store.job(id)))!.state,
        DownloadState.paused,
      );
      expect(find.text('Paused'), findsOneWidget);
      expect(find.byTooltip('Resume download'), findsOneWidget);
      await tap(tester, find.byTooltip('Cancel'));
      await settle(tester);
      expect(
        (await tester.runAsync(() => service.store.job(id)))!.state,
        DownloadState.cancelled,
      );
      expect(find.text('Fixture reader'), findsNothing);
      expect(find.byKey(const Key('download-queue')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('offline metadata filters use book and inherited series fields', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final catalogue = CatalogueStore(database, 'reader-account');
      await catalogue.stage('metadata', [
        for (final genre in ['Fantasy', 'Adventure']) ...[
          CatalogueItem(
            kind: CatalogueKind.series,
            id: genre,
            title: genre,
            metadata: CatalogueMetadata(
              genres: [genre],
              publisher: 'Fixture Publisher',
            ),
          ),
          CatalogueItem(
            kind: CatalogueKind.book,
            id: 'book-$genre',
            title: '$genre book',
            seriesId: genre,
            metadata: const CatalogueMetadata(
              mediaType: 'application/epub+zip',
            ),
          ),
        ],
      ]);
      await catalogue.publish('metadata', DateTime(2026), () => true);
      for (final genre in ['Fantasy', 'Adventure']) {
        final original = readerManifest(book: 'book-$genre');
        final manifest = ReaderManifest(
          accountId: original.accountId,
          bookId: original.bookId,
          revision: original.revision,
          title: '$genre book',
          seriesId: genre,
          documentType: 'application/epub+zip',
          pages: original.pages,
        );
        final id = await service.store.enqueue(manifest);
        await service.store.state(id, DownloadState.complete);
      }
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Fantasy book'), findsOneWidget);
    expect(find.text('Adventure book'), findsOneWidget);
    // Downloads uses the shared filter bar: visible search, reading chips
    // without the redundant Downloaded toggle, a sort label and filters.
    expect(find.byType(InkFilterBar), findsOneWidget);
    expect(find.byKey(const Key('downloads-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('reading-filter-unread')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reading-filter-downloaded')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('downloads-sort')),
        matching: find.text('A–Z'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('downloads-filters')));
    await tester.pumpAndSettle();
    // Reading status and Downloaded live in the bar, not in the sheet.
    expect(find.text('Downloaded'), findsNothing);
    expect(find.text('Show results (2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-genres-Fantasy')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Show results (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filters-apply')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-count'))).data,
      '1',
    );
    await tester.pumpAndSettle();
    expect(find.text('Fantasy book'), findsOneWidget);
    expect(find.text('Adventure book'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'downloaded series group volumes across libraries at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          ReaderManifest book(String id, String title, String library) =>
              ReaderManifest(
                accountId: 'reader-account',
                bookId: id,
                revision: 'revision',
                title: title,
                libraryId: library,
                seriesId: id.startsWith('alpha')
                    ? 'series-alpha'
                    : 'series-beta',
                pages: readerManifest().pages,
              );
          await tester.runAsync(() async {
            for (final manifest in [
              book('alpha', 'Alpha volume 1', 'manga'),
              book('alpha2', 'Alpha volume 2', 'manga'),
              book('beta', 'Beta volume 1', 'ebooks'),
            ]) {
              final id = await service.store.enqueue(manifest);
              await service.store.state(id, DownloadState.complete);
            }
            await service.store.enqueue(
              book('pending', 'Pending book', 'manga'),
            );
            final other = DownloadStore(
              database,
              'another-account',
              service.store.directory,
            );
            final id = await other.enqueue(
              readerManifest(account: 'another-account', book: 'private'),
            );
            await other.state(id, DownloadState.complete);
          });
          await tester.runAsync(() async {
            final catalogue = CatalogueStore(database, 'reader-account');
            await catalogue.stage('offline-series', [
              entry(
                'series-alpha',
                kind: CatalogueKind.series,
                title: 'Alpha Manga',
              ),
              entry(
                'series-beta',
                kind: CatalogueKind.series,
                title: 'Beta Ebook',
              ),
            ]);
            await catalogue.publish(
              'offline-series',
              DateTime.now(),
              () => true,
            );
          });
          final router = GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const DownloadsScreen()),
              GoRoute(
                path: '/downloads/series/:id',
                builder: (_, state) =>
                    DownloadsScreen(seriesId: state.pathParameters['id']),
              ),
              GoRoute(
                name: 'series-reader',
                path: '/catalogue/:kind/:id/read/:bookId',
                builder: (_, state) => Scaffold(
                  body: Text('Reader ${state.pathParameters['bookId']}'),
                ),
              ),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          );
          await settle(tester);
          final scrollable = find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first;
          // Storage summary and the active queue (one pending book) precede
          // the pinned tools and the series/books sections.
          expect(find.byKey(const Key('download-storage')), findsNothing);
          expect(find.byKey(const Key('download-queue')), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Alpha Manga'),
            200,
            scrollable: scrollable,
          );
          expect(find.text('Alpha Manga'), findsOneWidget);
          expect(find.text('2 items'), findsOneWidget);
          expect(find.textContaining('2 volumes'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Beta Ebook'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Beta Ebook'), findsOneWidget);
          // Pending downloads share this page above the completed gallery.
          expect(find.text('Fixture reader'), findsNothing);
          expect(find.text('Alpha volume 1'), findsNothing);
          expect(find.text('Alpha volume 2'), findsNothing);
          expect(find.text('Beta volume 1'), findsNothing);
          expect(find.byType(SegmentedButton<bool>), findsNothing);
          expect(find.text('Storage and network'), findsNothing);
          expect(find.byKey(const Key('library-selector')), findsNothing);
          // List layout by default, grouped in Series and Books sections.
          expect(find.byType(CatalogueGrid), findsNothing);
          expect(find.byKey(const Key('downloads-series')), findsOneWidget);
          // Both groups are comic series (the second is only named Ebook).
          expect(find.byKey(const Key('downloads-books')), findsNothing);
          await tester.ensureVisible(find.text('Alpha Manga'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Alpha Manga'));
          await settle(tester);
          expect(find.text('Alpha volume 1'), findsOneWidget);
          // Downloaded volumes use the shared series volume rows.
          expect(find.byType(VolumeRow), findsWidgets);
          expect(find.byType(CatalogueGrid), findsNothing);
          expect(find.byTooltip('Show grid'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Alpha volume 2'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.text('Alpha volume 2'), findsOneWidget);
          expect(find.text('Beta volume 1'), findsNothing);
          await tester.ensureVisible(find.text('Alpha volume 1'));
          await tester.tap(find.text('Alpha volume 1'));
          await settle(tester);
          expect(find.text('Reader alpha'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await settle(tester);
          router.dispose();
        },
      );
    }
  }

  testWidgets('download catalogue searches, sorts and confirms removal', (
    tester,
  ) async {
    final alpha = ReaderManifest(
      accountId: 'reader-account',
      bookId: 'alpha',
      revision: 'revision',
      title: 'Alpha',
      seriesId: 'series-a',
      pages: readerManifest().pages,
    );
    final beta = ReaderManifest(
      accountId: 'reader-account',
      bookId: 'beta',
      revision: 'revision',
      title: 'Beta',
      seriesId: 'series-a',
      pages: readerManifest().pages,
    );
    String? removedId;
    late String alphaId;
    await tester.runAsync(() async {
      alphaId = await service.store.enqueue(alpha);
      await service.store.state(alphaId, DownloadState.complete);
      await service.store.state(
        await service.store.enqueue(beta),
        DownloadState.complete,
      );
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: DownloadsScreen(
            seriesId: 'series-a',
            onRemoveDownload: (id) async {
              removedId = id;
              await service.store.state(id, DownloadState.cancelled);
            },
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('downloads-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title Z–A').last);
    await tester.pumpAndSettle();
    final betaPoint = tester.getTopLeft(find.text('Beta'));
    final alphaPoint = tester.getTopLeft(find.text('Alpha'));
    expect(
      betaPoint.dy < alphaPoint.dy ||
          betaPoint.dy == alphaPoint.dy && betaPoint.dx < alphaPoint.dx,
      isTrue,
    );
    if (find
        .byKey(const Key('open-search'))
        .hitTestable()
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const Key('open-search')).hitTestable().last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('downloads-search')), 'Alpha');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(VolumeRow), matching: find.text('Alpha')),
      findsOneWidget,
    );
    expect(find.text('Beta'), findsNothing);
    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep download'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => service.store.job(alphaId)))!.state,
      DownloadState.complete,
    );
    await tester.tap(find.byTooltip('Remove download'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Remove download'));
    expect(removedId, alphaId);
    expect(
      (await tester.runAsync(() => service.store.job(alphaId)))!.state,
      DownloadState.cancelled,
    );
    expect(
      find.descendant(of: find.byType(VolumeRow), matching: find.text('Alpha')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await settle(tester);
  });

  testWidgets(
    'removing a volume clears every completed revision in its series',
    (tester) async {
      final ids = <String>[];
      await tester.runAsync(() async {
        for (final revision in ['old', 'new']) {
          final manifest = ReaderManifest(
            accountId: 'reader-account',
            bookId: 'alpha',
            revision: revision,
            title: 'Alpha',
            seriesId: 'series-a',
            pages: readerManifest().pages,
          );
          final id = await service.store.enqueue(manifest);
          ids.add(id);
          await service.store.state(id, DownloadState.complete);
        }
      });
      final removed = <String>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DownloadsScreen(
              seriesId: 'series-a',
              onRemoveDownload: (id) async {
                removed.add(id);
                await service.store.state(id, DownloadState.cancelled);
              },
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('1 book'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove download'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Remove download'));
      expect(removed, unorderedEquals(ids));
      expect(
        await tester.runAsync(() => service.store.completedSeries().first),
        isEmpty,
      );
      expect(find.text('Alpha'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
    },
  );

  testWidgets(
    'volume download tap queues its book without opening the reader',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: VolumeListTile(
                item: entry('volume-book', title: 'Volume name'),
              ),
            ),
          ),
          GoRoute(
            path: '/catalogue/:kind/:id/read/:bookId',
            name: 'series-reader',
            builder: (_, state) => Scaffold(
              body: Text('Reading ${state.pathParameters['bookId']}'),
            ),
          ),
          GoRoute(
            path: '/downloads',
            builder: (_, _) => const Scaffold(body: Text('Download queue')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      await tap(tester, find.byTooltip('Download volume'));
      expect(find.text('Volume name'), findsOneWidget);
      expect(find.text('Reading volume-book'), findsNothing);
      final jobs = (await tester.runAsync(service.store.jobs))!;
      expect(jobs, hasLength(1));
      expect(jobs.single.manifest.bookId, 'volume-book');
      await tester.runAsync(
        () => service.store.state(jobs.single.id, DownloadState.queued),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Manage download · Queued'));
      await tester.pumpAndSettle();
      expect(find.text('Download queue'), findsOneWidget);
      expect((await tester.runAsync(service.store.jobs))!, hasLength(1));
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volume name'));
      await tester.pumpAndSettle();
      expect(find.text('Reading volume-book'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await settle(tester);
    },
  );

  testWidgets(
    'shared row removes all completed revisions while retaining the locator',
    (tester) async {
      final ids = <String>[];

      await tester.runAsync(() async {
        for (final revision in ['first', 'second']) {
          final id = await service.store.enqueue(
            readerManifest(book: 'volume-book', revision: revision),
          );
          ids.add(id);
          await service.store.state(id, DownloadState.complete);
        }
        await database.customStatement(
          "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('reader-account','volume-book','second',2,0.5)",
        );
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VolumeListTile(
                item: entry('volume-book', title: 'Volume name'),
                onRemoveDownload: (id) =>
                    service.store.state(id, DownloadState.cancelled),
              ),
            ),
          ),
        ),
      );

      await settle(tester);

      await tester.tap(find.byTooltip('Remove download'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this download?'), findsOneWidget);

      await tap(tester, find.text('Remove download'));
      for (final id in ids) {
        expect(
          (await tester.runAsync(() => service.store.job(id)))!.state,
          DownloadState.cancelled,
        );
      }
      expect(
        (await tester.runAsync(
          () => database.select(database.readerPositions).getSingle(),
        ))!.pageIndex,
        2,
      );
      expect(find.byTooltip('Download volume'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());

      container.dispose();
      await settle(tester);
    },
  );

  test(
    'coordinator removal deletes revisions while retaining reading progress',
    () async {
      final ids = <String>[];
      for (final revision in ['first', 'second']) {
        final id = await service.store.enqueue(
          readerManifest(book: 'volume-book', revision: revision),
        );
        ids.add(id);
        await service.store.state(id, DownloadState.complete);
      }
      await database.customStatement(
        "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('reader-account','volume-book','second',2,0.5)",
      );
      for (final id in ids) {
        await service.cancel(id);
        expect((await service.store.job(id))!.state, DownloadState.cancelled);
      }
      expect(
        (await database.select(database.readerPositions).getSingle()).pageIndex,
        2,
      );
    },
  );

  testWidgets('download settings retain persistent quota and Wi-Fi controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DownloadSettingsPanel()),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Storage and network'), findsOneWidget);
    final quotaSlider = find.byKey(const Key('download-quota'));
    await tester.ensureVisible(quotaSlider);
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(quotaSlider);
    slider.onChanged!(512);
    await tester.pump();
    expect(service.store.quota, defaultDownloadQuota);
    tester.widget<Slider>(quotaSlider).onChangeEnd!(512);
    await settle(tester);
    expect(service.store.quota, 512 * 1024 * 1024);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tap(tester, find.byType(SwitchListTile));
    expect(service.store.wifiOnly, isFalse);
    final reopened = DownloadStore(
      database,
      'reader-account',
      service.store.directory,
    );
    await tester.runAsync(reopened.loadSettings);
    expect(reopened.quota, 512 * 1024 * 1024);
    expect(reopened.wifiOnly, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  });

  testWidgets(
    'explicit unread saves local locator and intent before dismissing the progress sheet',
    (tester) async {
      await tester.runAsync(
        () => service.sync.store.save(readerManifest(), ReaderLocator(2, .4)),
      );
      service.sync.paused = true;
      var changed = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ProgressSheet(
                      manifest: readerManifest(),
                      onChanging: () => changed = true,
                    ),
                  ),
                  child: const Text('Open progress'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open progress'));
      await settle(tester);
      await tap(tester, find.text('Mark unread and restart'));
      await settle(tester);
      expect(changed, isTrue);
      expect(
        (await tester.runAsync(
          () =>
              ReaderStore(database, 'reader-account').locator(readerManifest()),
        ))!.pageIndex,
        0,
      );
      expect(
        (await tester.runAsync(service.sync.store.pending))!.last.operation,
        ProgressOperation.markUnread,
      );
      expect(find.text('Reading progress'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'conflict sheet exposes both candidates and applies the chosen server position',
    (tester) async {
      await tester.runAsync(() async {
        await service.sync.store.save(
          readerManifest(),
          ReaderLocator(0),
          operation: ProgressOperation.rewind,
        );
        await service.sync.store.state(
          (await service.sync.store.pending()).single,
          'conflict',
          remote: const ProgressSnapshot(
            revision: 'revision-a',
            pageIndex: 2,
            version: 'server',
          ),
        );
      });
      service.sync.paused = true;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ProgressSheet(
                      manifest: readerManifest(),
                      onChanging: () {},
                    ),
                  ),
                  child: const Text('Open progress'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open progress'));
      await settle(tester);
      expect(find.textContaining('Server: Page 3'), findsOneWidget);
      await tap(tester, find.text('Use server progress'));
      await settle(tester);
      expect(await tester.runAsync(service.sync.store.pending), isEmpty);
      expect(
        (await tester.runAsync(
          () =>
              ReaderStore(database, 'reader-account').locator(readerManifest()),
        ))!.pageIndex,
        2,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'reader reset moves the viewport and ignores the disposed viewport locator',
    (tester) async {
      // This regression asserts a two-page spread, independently of the device.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manifest = readerManifest();
      final client = fixtureClient(
        savedSession.endpoint,
        savedSession.credentials,
        FixtureAdapter((_) => throw StateError('No implicit network')),
      );
      final repository = ReaderRepository(
        ReaderStore(database, 'reader-account'),
        service.assets,
        client,
        PageNetworkGate(),
        isCurrent: () => true,
      );
      service.sync.paused = true;
      await tester.runAsync(() async {
        await repository.store.saveManifest(manifest);
        await repository.store.saveLocator(manifest, ReaderLocator(2, .3));
      });
      for (var page = 0; page < 4; page++) {
        repository.memory.put(
          EncodedPage(
            key: manifest.key(page),
            bytes: fixtureRaster,
            mediaType: 'image/png',
          ),
        );
      }
      container.dispose();
      container = ProviderContainer(
        overrides: [
          offlineCoordinatorProvider.overrideWith((ref) async => service),
          readerRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ReaderScreen(bookId: manifest.bookId)),
        ),
      );
      await settle(tester);
      await settleReaderImages(tester);
      await tester.tapAt(
        Offset(20, tester.getCenter(find.byType(ReaderScreen)).dy),
      );
      await settle(tester);
      expect(find.text('p. 3–4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('reader-more')));
      await settle(tester);
      await tester.tap(find.text('Reading progress').last);
      await settle(tester);
      await tap(tester, find.text('Mark unread and restart'));
      await settle(tester);
      await settleReaderImages(tester);
      expect(find.text('p. 1–2'), findsOneWidget);
      expect(
        (await tester.runAsync(() => repository.store.locator(manifest)))!
            .pageIndex,
        0,
      );
      expect(
        (await tester.runAsync(service.sync.store.pending))!.last.operation,
        ProgressOperation.markUnread,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      repository.close();
      client.close();
    },
  );
}
