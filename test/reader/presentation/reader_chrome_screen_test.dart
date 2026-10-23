import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/app/widgets/ink_surface.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/settings/application/ui_preferences_provider.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/reader/application/reader_providers.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';
import 'package:inkora/reader/data/reader_repository.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_chrome.dart';
import 'package:inkora/reader/presentation/reader_details.dart';
import 'package:inkora/reader/presentation/reader_screen.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../../support/accessibility.dart';
import '../../support/connection_fakes.dart';
import '../../support/reader_fakes.dart';
import '../../support/reader_widget_support.dart';

Future<Object?> _backEvent(WidgetTester tester, String method) async {
  final channel = SystemChannels.backGesture;
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall(method, {
            'touchOffset': [0.0, 300.0],
            'progress': method == 'updateBackGestureProgress' ? .4 : 0.0,
            'swipeEdge': 0,
          }),
        ),
        null,
      );
  return response == null ? null : channel.codec.decodeEnvelope(response);
}

/// Predictive back on the top route: start/update/cancel keeps it,
/// start/update/commit pops it. When the framework declines the gesture for
/// a popup or sheet route, Android delivers a system back instead.
Future<void> _predictiveBack(WidgetTester tester, Finder visible) async {
  if (await _backEvent(tester, 'startBackGesture') == true) {
    await _backEvent(tester, 'updateBackGestureProgress');
    await tester.pump();
    await _backEvent(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(visible, findsWidgets);
    await _backEvent(tester, 'startBackGesture');
    await _backEvent(tester, 'updateBackGestureProgress');
    await tester.pump();
    await _backEvent(tester, 'commitBackGesture');
  } else {
    expect(visible, findsWidgets);
    await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  await settleReaderImages(tester);
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1280, 800),
    const Size(800, 1280),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'raster reader chrome at $size/$scale: title, position subtitle, one action row and More menu',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final db = AppDatabase(NativeDatabase.memory());
          final dir = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('inkora-chrome-test-'),
          ))!;
          await tester.runAsync(() async {
            final store = CatalogueStore(
              db,
              'reader-account',
              applyLibraryVisibility: false,
            );
            await store.stage('g', [
              const CatalogueItem(
                kind: CatalogueKind.series,
                id: 'series',
                title: 'Another',
              ),
              const CatalogueItem(
                kind: CatalogueKind.book,
                id: 'reader-book',
                title: 'Another T01',
                seriesId: 'series',
                number: 1,
              ),
            ]);
            await store.publish('g', DateTime.now(), () => true);
          });
          final client = fixtureClient(
            savedSession.endpoint,
            savedSession.credentials,
            FixtureAdapter((options) => jsonResponse(userJson)),
          );
          final repository = ReaderRepository(
            ReaderStore(db, 'reader-account'),
            ReaderAssetStore(
              db,
              Directory('${dir.path}/cache'),
              Directory('${dir.path}/downloads'),
            ),
            client,
            PageNetworkGate(),
            isCurrent: () => true,
          );
          final manifest = readerManifest(count: 20);
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(Future.value(db)),
              uiPreferencesProvider.overrideWith(
                (ref) => Stream.value(const UiPreferences()),
              ),
              readerRepositoryProvider.overrideWith((ref) async => repository),
              catalogueRepositoryProvider.overrideWith((ref) async => null),
              coverRepositoryProvider.overrideWith((ref) async => null),
              downloadedBooksProvider.overrideWith((ref) => Stream.value([])),
              openReaderProvider(manifest.bookId).overrideWith(
                (ref) async =>
                    OpenReader(manifest, FixturePageSource(), ReaderLocator(4)),
              ),
              readingSettingsProvider(manifest.bookId).overrideWith(
                (ref) => Stream.value(
                  const ReadingSettings(layout: ReadingLayout.single),
                ),
              ),
            ],
          );
          final router = GoRouter(
            initialLocation: '/reader/${manifest.bookId}',
            routes: [
              GoRoute(
                name: 'reader-parent',
                path: '/reader-parent/:id',
                builder: (_, _) => const Scaffold(body: Text('Parent facts')),
              ),
              GoRoute(
                name: 'reader',
                path: '/reader/:id',
                builder: (_, state) =>
                    ReaderScreen(bookId: state.pathParameters['id']!),
              ),
            ],
          );
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(routerConfig: router),
              ),
            );
            await _frames(tester);
            expect(find.byType(ReaderTopBar), findsNothing);
            await tester.tapAt(Offset(20, size.height / 2));
            await _frames(tester);

            // Top bar: series title, "Another T01 · p. 5/20", details action.
            expect(find.text('Another'), findsOneWidget);
            expect(find.text('Another T01 · p. 5/20'), findsOneWidget);
            expect(find.byTooltip('Book details'), findsOneWidget);
            expect(
              find.byKey(const Key('reader-series')).hitTestable(),
              findsOneWidget,
            );
            final retainedReader = tester.state(find.byType(ReaderScreen));
            await tester.tap(find.byKey(const Key('reader-details')));
            await _frames(tester);
            expect(find.byType(ReaderBookDetails), findsOneWidget);
            expect(
              tester.state(find.byType(ReaderScreen)),
              same(retainedReader),
            );
            await _predictiveBack(tester, find.byType(ReaderBookDetails));
            expect(find.byType(ReaderBookDetails), findsNothing);
            expect(find.text('Another T01 · p. 5/20'), findsOneWidget);
            await tester.tap(find.byKey(const Key('reader-series')));
            await _frames(tester);
            expect(find.text('Parent facts'), findsOneWidget);
            await _predictiveBack(tester, find.text('Parent facts'));
            expect(
              tester.state(find.byType(ReaderScreen)),
              same(retainedReader),
            );
            expect(find.text('Another T01 · p. 5/20'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(ReaderPanel),
                matching: find.byType(Divider),
              ),
              findsNothing,
            );
            for (final panel in find.byType(ReaderPanel).evaluate()) {
              final surface = tester.widget<InkSurface>(
                find.descendant(
                  of: find.byElementPredicate((element) => element == panel),
                  matching: find.byType(InkSurface),
                ),
              );
              expect(surface.opacity, InkOverlaySurface.opacity);
            }
            // Progress line and the single action row.
            expect(find.text('p. 5'), findsOneWidget);
            expect(find.text('25 % · 15 pages left'), findsOneWidget);
            final labels = ['Pages', 'Bookmarks', 'Settings', 'More'];
            final tops = {
              for (final label in labels)
                tester.getTopLeft(find.byTooltip(label)).dy,
            };
            expect(tops, hasLength(1), reason: 'one row of actions');
            for (final label in labels) {
              expect(find.byTooltip(label).hitTestable(), findsOneWidget);
            }
            expect(find.text('Finish volume'), findsNothing);
            await expectAccessibilityGuidelines(tester);

            // More holds the less frequent commands; predictive back closes it.
            await tester.tap(find.byKey(const Key('reader-more')));
            await tester.pumpAndSettle();
            for (final entry in [
              'Finish volume',
              'Reading progress',
              'Refresh book',
            ]) {
              expect(find.text(entry), findsOneWidget);
            }
            await _predictiveBack(tester, find.text('Refresh book'));
            expect(find.text('Refresh book'), findsNothing);
            expect(find.byType(ReaderTopBar), findsOneWidget);

            // Settings opens the live editor; predictive back closes the sheet
            // and leaves the reader (and its position) in place.
            await tester.tap(find.byTooltip('Settings'));
            await _frames(tester);
            expect(find.byType(ReaderSettingsSheet), findsOneWidget);
            expect(find.text('Save'), findsNothing);
            await expectAccessibilityGuidelines(tester);
            await _predictiveBack(tester, find.byType(ReaderSettingsSheet));
            expect(find.byType(ReaderSettingsSheet), findsNothing);
            expect(find.text('p. 5'), findsOneWidget);

            // Next page updates the subtitle and progress line together.
            await tester.tap(find.byTooltip('Next page'));
            await _frames(tester);
            expect(find.text('Another T01 · p. 6/20'), findsOneWidget);
            expect(find.text('30 % · 14 pages left'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
            await tester.pump(const Duration(milliseconds: 20));
            router.dispose();
            repository.close();
            client.close();
            await tester.runAsync(db.close);
            await tester.runAsync(() => dir.delete(recursive: true));
          }
        },
      );
    }
  }
}
