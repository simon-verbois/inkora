import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/inkora_app.dart';
import 'package:inkora/app/release_information.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/connection/application/session_controller.dart';
import 'package:inkora/features/library/application/catalogue_providers.dart';
import 'package:inkora/features/library/application/cover_providers.dart';
import 'package:inkora/features/library/application/discovery_providers.dart';
import 'package:inkora/features/library/data/catalogue_repository.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/data/cover_repository.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/offline/application/offline_coordinator.dart';
import 'package:inkora/reader/application/reader_providers.dart';

import 'catalogue_fakes.dart';
import 'connection_fakes.dart';

final class UiHarness {
  UiHarness._(this.database, this.repository, this.container);
  final AppDatabase database;
  final CatalogueRepository repository;
  final ProviderContainer container;
  bool _closed = false;

  static Future<UiHarness> create(
    WidgetTester tester, {
    UiPreferences preferences = const UiPreferences(),
    List<ResumeEntry>? resumeEntries,
    DateTime Function()? discoveryClock,
    CoverRepository? covers,
    List<CatalogueItem>? catalogue,
    bool refreshCatalogue = true,
    AppDatabase? databaseOverride,
    OfflineCoordinator Function(AppDatabase)? offlineFactory,
  }) async {
    final database = databaseOverride ?? AppDatabase(NativeDatabase.memory());
    final remote = FakeCatalogueRemote();
    remote.items[CatalogueKind.library] = [
      entry('library-a', kind: CatalogueKind.library, title: 'Manga shelf'),
      entry('library-b', kind: CatalogueKind.library, title: 'Graphic novels'),
    ];
    remote.items[CatalogueKind.series] = [
      entry('series-a', kind: CatalogueKind.series, title: 'Moonlit District'),
      entry(
        'series-b',
        kind: CatalogueKind.series,
        title: 'Atlas Nine',
        libraryId: 'library-b',
      ),
    ];
    remote.items[CatalogueKind.book] = [
      entry('book-a', title: 'Moonlit District · Volume 3', number: 3),
      entry(
        'book-b',
        title: 'Atlas Nine · Volume 1',
        libraryId: 'library-b',
        seriesId: 'series-b',
      ),
      entry('removed', title: 'Unavailable volume', available: false),
    ];
    if (catalogue != null) {
      for (final kind in CatalogueKind.values) {
        remote.items[kind] = catalogue
            .where((item) => item.kind == kind)
            .toList();
      }
    }
    final repository = CatalogueRepository(
      CatalogueStore(database, savedSession.accountId),
      remote,
    );
    OfflineCoordinator? offline;
    await tester.runAsync(() async {
      if (refreshCatalogue) await repository.refresh();
      await UiPreferencesStore(database).save(
        preferences.copyWith(
          setupCompleted: true,
          locale: preferences.locale ?? 'en',
        ),
      );
      offline = offlineFactory?.call(database);
    });
    final container = ProviderContainer(
      overrides: [
        // App-wide navigation fixtures keep asset I/O outside fake widget time.
        // Packaged files and About rendering have their own focused coverage.
        releaseInformationProvider.overrideWith(
          (ref) async => const ReleaseInformation('0.1.0', [
            ChangelogSection('Unreleased', [
              ChangelogBlock(
                ChangelogBlockKind.bullet,
                'Fixture release notes.',
              ),
            ]),
          ]),
        ),
        if (discoveryClock != null)
          discoveryClockProvider.overrideWithValue(discoveryClock),
        if (resumeEntries != null)
          resumeEntriesProvider.overrideWith(
            (ref) => Stream.value(resumeEntries),
          ),
        databaseProvider.overrideWithValue(Future.value(database)),
        sessionStoreProvider.overrideWithValue(
          MemorySessionStore()..saved = savedSession,
        ),
        komgaClientFactoryProvider.overrideWithValue(
          (endpoint, credentials) => fixtureClient(
            endpoint,
            credentials,
            FixtureAdapter((options) => jsonResponse(userJson)),
          ),
        ),
        catalogueRepositoryProvider.overrideWith((ref) async => repository),
        coverRepositoryProvider.overrideWith((ref) async => covers),
        offlineCoordinatorProvider.overrideWith((ref) async => offline),
        readerRepositoryProvider.overrideWith((ref) async => null),
        if (offline == null)
          downloadsProvider.overrideWith((ref) => Stream.value([])),
        progressIntentsProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    return UiHarness._(database, repository, container);
  }

  Future<void> mount(
    WidgetTester tester, {
    double textScale = 1,
    Key? captureKey,
    bool settle = true,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: captureKey == null
            ? const InkoraApp()
            : RepaintBoundary(key: captureKey, child: const InkoraApp()),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 20));
    repository.close();
    await tester.runAsync(database.close);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
}
