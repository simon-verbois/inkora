import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/app/widgets/inkora_widgets.dart';
import 'package:inkora/core/storage/app_database.dart' hide DownloadJob;
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/presentation/catalogue_grid.dart';
import 'package:inkora/features/library/presentation/volume_browser.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/offline/data/download_store.dart';
import 'package:inkora/offline/presentation/downloads_screen.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';

import '../support/accessibility.dart';
import '../support/catalogue_fakes.dart';
import '../support/reader_fakes.dart';
import 'download_summary_test.dart' show asset;

const _mib = 1024 * 1024;

typedef _Shelf = ({List<DownloadedSeries> groups, List<DownloadJob> jobs});

Future<_Shelf> _shelf(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = DownloadStore(database, 'account', Directory('/unused'));
      final catalogue = CatalogueStore(database, 'account');
      await catalogue.stage('g', [
        entry(
          'series-a',
          kind: CatalogueKind.series,
          title: 'A considerably long series title for wrapping checks',
        ),
        entry('a1', title: 'Volume one', number: 1),
        entry('a2', title: 'Volume two', number: 2),
      ]);
      await catalogue.publish('g', DateTime(2026), () => true);
      ReaderManifest manifest(String id, {String? type}) => ReaderManifest(
        accountId: 'account',
        bookId: id,
        revision: 'r1',
        title: type == null ? 'Volume $id' : 'An ebook with a long title',
        seriesId: type == null ? 'series-a' : 'author',
        documentType: type,
        pages: readerManifest().pages,
      );
      for (final (id, type) in [
        ('a1', null),
        ('a2', null),
        ('novel', 'application/epub+zip'),
      ]) {
        await store.state(
          await store.enqueue(manifest(id, type: type)),
          DownloadState.complete,
        );
        await asset(database, '$id-0', book: id, bytes: 206 * _mib);
      }
      await store.enqueue(manifest('pending'));
      await store.state(
        await store.enqueue(manifest('broken')),
        DownloadState.failed,
        error: 'Download failed. Retry when ready.',
      );
      final shelf = (
        groups: await store.completedSeries(includeReadingStatus: true).first,
        jobs: await store.watch().first,
      );
      await database.close();
      return shelf;
    }))!;

Future<void> _mount(
  WidgetTester tester,
  _Shelf shelf, {
  required Size size,
  double scale = 1,
  String locale = 'en',
  List<String>? removed,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            DownloadsScreen(onRemoveDownload: (id) async => removed?.add(id)),
      ),
      GoRoute(
        path: '/downloads/series/:id',
        builder: (_, state) =>
            DownloadsScreen(seriesId: state.pathParameters['id']),
      ),
      GoRoute(
        name: 'reader',
        path: '/reader/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Reader ${state.pathParameters['id']}')),
      ),
      GoRoute(
        name: 'series-reader',
        path: '/catalogue/:kind/:id/read/:bookId',
        builder: (_, state) =>
            Scaffold(body: Text('Reader ${state.pathParameters['bookId']}')),
      ),
      GoRoute(
        path: '/settings/downloads',
        builder: (_, _) => const Scaffold(body: Text('Download settings page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coverRepositoryProvider.overrideWith((ref) async => null),
        offlineCoordinatorProvider.overrideWith((ref) async => null),
        downloadedReadingSeriesProvider.overrideWith(
          (ref) => Stream.value(shelf.groups),
        ),
        downloadsProvider.overrideWith((ref) => Stream.value(shelf.jobs)),
        downloadStorageProvider.overrideWith(
          (ref) async => (
            downloaded: 618 * _mib,
            reserved: 24 * _mib,
            cached: 51 * _mib,
            quota: 2048 * _mib,
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: AppStrings.localeFor(locale),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _scrollable => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  for (final size in const [Size(390, 844), Size(1280, 800), Size(800, 1280)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('downloads storage, queue and series rows at $size/$scale', (
        tester,
      ) async {
        final shelf = await _shelf(tester);
        final removed = <String>[];
        await _mount(tester, shelf, size: size, scale: scale, removed: removed);
        expect(find.text('642 MiB of 2 GiB used'), findsNothing);
        expect(find.text('Reserved · 24 MiB'), findsNothing);
        expect(find.text('Page cache · 51 MiB'), findsNothing);
        // Current transfer first (queued), the failed job counted.
        expect(find.byType(InkProgressRing), findsOneWidget);
        expect(find.textContaining('Failed: 1'), findsOneWidget);
        await tester.tap(find.byKey(const Key('download-queue-toggle')));
        await tester.pumpAndSettle();
        expect(find.byType(InkProgressRing), findsNWidgets(2));
        expect(find.text('Download failed'), findsOneWidget);
        expect(find.byTooltip('Retry download'), findsOneWidget);
        // Storage card, expanded queue and rows: 48 dp labelled targets.
        await expectAccessibilityGuidelines(tester, contrast: false);
        await tester.scrollUntilVisible(
          find.text('An ebook with a long title'),
          200,
          scrollable: _scrollable,
        );
        expect(find.text('Series'), findsOneWidget);
        expect(find.text('Books'), findsOneWidget);
        expect(find.text('2 volumes · 412 MiB'), findsOneWidget);
        expect(find.text('EPUB · 206 MiB · Unread'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Long press: menu, then a confirmed removal of both volumes.
        final row = find.byKey(const ValueKey('download-row-series:series-a'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.longPress(row);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove downloads'));
        await tester.pumpAndSettle();
        expect(find.text('Remove these downloads?'), findsOneWidget);
        expect(find.textContaining('Remove 2 volumes of'), findsOneWidget);
        await tester.tap(find.byKey(const Key('ink-confirm-accept')));
        await tester.pumpAndSettle();
        expect(removed, hasLength(2));
        // The series route lists its volumes with the shared rows.
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(VolumeRow), findsNWidgets(2));
        expect(find.text('Volume a1'), findsOneWidget);
        await expectAccessibilityGuidelines(tester, contrast: false);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('downloads keeps its grid option and the settings link', (
    tester,
  ) async {
    final shelf = await _shelf(tester);
    await _mount(tester, shelf, size: const Size(1280, 800));
    expect(find.byType(CatalogueGrid), findsNothing);
    await tester.tap(find.byKey(const Key('downloads-view')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogueGrid), findsOneWidget);
    expect(find.byKey(const Key('download-storage-settings')), findsNothing);
  });

  for (final locale in AppStrings.supportedLocales) {
    testWidgets('downloads fits ${locale.languageCode} at 390x844/200%', (
      tester,
    ) async {
      final shelf = await _shelf(tester);
      await _mount(
        tester,
        shelf,
        size: const Size(390, 844),
        scale: 2,
        locale: locale.languageCode,
      );
      await tester.tap(find.byKey(const Key('download-queue-toggle')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('An ebook with a long title'),
        200,
        scrollable: _scrollable,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
