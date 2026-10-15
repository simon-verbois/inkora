import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/features/library/data/catalogue_store.dart';
import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/reader_fakes.dart';

void main() {
  late AppDatabase database;
  late ReaderStore store;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = ReaderStore(database, 'reader-account');
  });
  tearDown(() => database.close());

  test('manual library application clears only owned descendants, including offline books', () async {
    final catalogue = CatalogueStore(database, store.accountId);
    await catalogue.stage('current', [
      const CatalogueItem(
        kind: CatalogueKind.series,
        id: 'series',
        title: 'Series',
        libraryId: 'library',
      ),
      const CatalogueItem(
        kind: CatalogueKind.book,
        id: 'reader-book',
        title: 'Book',
        libraryId: 'library',
        seriesId: 'series',
      ),
      const CatalogueItem(
        kind: CatalogueKind.book,
        id: 'moved-book',
        title: 'Moved',
        libraryId: 'other-library',
        seriesId: 'other-series',
      ),
      const CatalogueItem(
        kind: CatalogueKind.series,
        id: 'moved-series',
        title: 'Moved series',
        libraryId: 'other-library',
      ),
    ]);
    await catalogue.publish('current', DateTime.utc(2026, 10, 13), () => true);
    await store.saveManifest(readerManifest(book: 'offline-book'));
    await store.saveManifest(readerManifest(book: 'moved-book'));
    final moved = readerManifest(book: 'offline-moved-book');
    await store.saveManifest(
      ReaderManifest(
        accountId: moved.accountId,
        bookId: moved.bookId,
        revision: moved.revision,
        title: moved.title,
        pages: moved.pages,
        libraryId: 'library',
        seriesId: 'moved-series',
      ),
    );
    await store.saveLocator(readerManifest(), ReaderLocator(2, .4));
    for (final (scope, id) in [
      (SettingsScope.series, 'series'),
      (SettingsScope.book, 'reader-book'),
      (SettingsScope.book, 'offline-book'),
      (SettingsScope.book, 'moved-book'),
      (SettingsScope.series, 'other-series'),
      (SettingsScope.library, 'other-library'),
      (SettingsScope.series, 'moved-series'),
      (SettingsScope.book, 'offline-moved-book'),
    ]) {
      await store.saveOverrides(
        scope,
        id,
        const ReadingOverrides(mode: ReadingMode.manga, spacing: 16),
      );
    }
    final other = ReaderStore(database, 'another-account');
    await other.saveOverrides(
      SettingsScope.book,
      'reader-book',
      const ReadingOverrides(mode: ReadingMode.manga),
    );
    await store.applyLibraryDefaults(
      'library',
      const ReadingOverrides(mode: ReadingMode.webtoon),
    );
    for (final (scope, id) in [
      (SettingsScope.series, 'series'),
      (SettingsScope.book, 'reader-book'),
      (SettingsScope.book, 'offline-book'),
    ]) {
      expect((await store.overrides(scope, id)).mode, isNull);
    }
    for (final (scope, id) in [
      (SettingsScope.book, 'moved-book'),
      (SettingsScope.series, 'other-series'),
      (SettingsScope.library, 'other-library'),
      (SettingsScope.series, 'moved-series'),
      (SettingsScope.book, 'offline-moved-book'),
    ]) {
      expect((await store.overrides(scope, id)).mode, ReadingMode.manga);
    }
    expect(
      (await other.overrides(SettingsScope.book, 'reader-book')).mode,
      ReadingMode.manga,
    );
    expect(
      (await store.settings(readerManifest()).first).mode,
      ReadingMode.webtoon,
    );
    expect(
      (await store.settings(readerManifest(book: 'future-book')).first).mode,
      ReadingMode.webtoon,
    );
    expect((await store.locator(readerManifest())).fraction, .4);
    await expectLater(
      store.applyLibraryDefaults('', const ReadingOverrides()),
      throwsArgumentError,
    );
    expect(
      (await store.settings(readerManifest()).first).mode,
      ReadingMode.webtoon,
    );
  });

  test(
    'identical and unrelated preference saves do not emit reader settings',
    () async {
      final emitted = <ReadingSettings>[];
      var writes = 0;
      final changes = database.tableUpdates().listen((_) => writes++);
      final subscription = store.settings(readerManifest()).listen(emitted.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      const overrides = ReadingOverrides(mode: ReadingMode.manga);
      await store.saveOverrides(SettingsScope.library, 'library', overrides);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final before = writes;
      await store.saveOverrides(SettingsScope.library, 'library', overrides);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(writes, before);
      await store.saveOverrides(
        SettingsScope.book,
        'unrelated-book',
        const ReadingOverrides(spacing: 16),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted.map((s) => s.mode), [
        ReadingMode.comics,
        ReadingMode.manga,
      ]);
      await subscription.cancel();
      await changes.cancel();
    },
  );

  test(
    'book reset binds to library defaults and follows later library changes',
    () async {
      final manifest = readerManifest();
      await store.saveOverrides(
        SettingsScope.global,
        '',
        const ReadingOverrides(background: ReadingBackground.sepia),
      );
      await store.saveOverrides(
        SettingsScope.library,
        manifest.libraryId!,
        const ReadingOverrides(mode: ReadingMode.webtoon, spacing: 12),
      );
      await store.saveOverrides(
        SettingsScope.series,
        manifest.seriesId!,
        const ReadingOverrides(mode: ReadingMode.manga),
      );
      expect((await store.settings(manifest).first).mode, ReadingMode.manga);
      await store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        const ReadingOverrides(libraryDefaults: true),
      );
      var effective = await store.settings(manifest).first;
      expect(effective.mode, ReadingMode.webtoon);
      expect(effective.spacing, 12);
      expect(effective.background, ReadingBackground.sepia);
      await store.saveOverrides(
        SettingsScope.library,
        manifest.libraryId!,
        const ReadingOverrides(mode: ReadingMode.comics, spacing: 4),
      );
      effective = await store.settings(manifest).first;
      expect(effective.mode, ReadingMode.comics);
      expect(effective.spacing, 4);
      expect(
        (await ReaderStore(
          database,
          'another-account',
        ).settings(manifest).first).background,
        ReadingBackground.black,
      );
      final persisted = await store.overrides(
        SettingsScope.book,
        manifest.bookId,
      );
      expect(persisted.libraryDefaults, isTrue);
      expect(
        ReadingOverrides.fromJson(persisted.toJson()).libraryDefaults,
        isTrue,
      );
      expect(ReadingOverrides.fromJson({}).libraryDefaults, isFalse);
      await expectLater(
        store.saveOverrides(
          SettingsScope.library,
          manifest.libraryId!,
          const ReadingOverrides(libraryDefaults: true),
        ),
        throwsArgumentError,
      );
    },
  );

  test('nullable global/library/series/book overrides merge and explicit zero/false win', () async {
    final manifest = readerManifest();
    await store.saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(
        mode: ReadingMode.webtoon,
        direction: ReadingDirection.rightToLeft,
        spacing: 16,
        spreads: true,
      ),
    );
    await store.saveOverrides(
      SettingsScope.library,
      'library',
      const ReadingOverrides(fit: ReadingFit.width, spacing: 24),
    );
    await store.saveOverrides(
      SettingsScope.series,
      'series',
      const ReadingOverrides(background: ReadingBackground.sepia, spacing: 32),
    );
    await store.saveOverrides(
      SettingsScope.book,
      manifest.bookId,
      const ReadingOverrides(spacing: 0, spreads: false),
    );
    final settings = await store.settings(manifest).first;
    expect(settings.mode, ReadingMode.webtoon);
    expect(settings.direction, ReadingDirection.rightToLeft);
    expect(settings.fit, ReadingFit.width);
    expect(settings.background, ReadingBackground.sepia);
    expect(settings.spacing, 0);
    expect(settings.spreads, isFalse);
  });
  test('clearing a book override inherits subsequent parent changes through the stream', () async {
    final manifest = readerManifest();
    await store.saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(spacing: 16),
    );
    await store.saveOverrides(
      SettingsScope.book,
      manifest.bookId,
      const ReadingOverrides(spacing: 32),
    );
    final values = <double>[];
    final subscription = store
        .settings(manifest)
        .listen((s) => values.add(s.spacing));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.saveOverrides(
      SettingsScope.book,
      manifest.bookId,
      const ReadingOverrides(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.saveOverrides(
      SettingsScope.global,
      '',
      const ReadingOverrides(spacing: 24),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await subscription.cancel();
    expect(values, [32, 16, 24]);
  });
  test(
    'scope and account isolation apply to preferences, manifests and locators',
    () async {
      final manifest = readerManifest();
      await store.saveManifest(manifest);
      await store.saveLocator(manifest, ReaderLocator(2, .45));
      await store.saveOverrides(
        SettingsScope.book,
        manifest.bookId,
        const ReadingOverrides(mode: ReadingMode.webtoon),
      );
      final other = ReaderStore(database, 'other');
      expect(await other.manifest(manifest.bookId), isNull);
      expect(
        (await other.settings(readerManifest(account: 'other')).first).mode,
        ReadingMode.paged,
      );
      expect(
        (await other.locator(readerManifest(account: 'other'))).pageIndex,
        0,
      );
      expect(
        (await store.settings(readerManifest(book: 'other-book')).first).mode,
        ReadingMode.paged,
      );
      expect(
        () => store.saveLocator(
          readerManifest(account: 'other'),
          ReaderLocator(0),
        ),
        throwsArgumentError,
      );
    },
  );
  test('revision change resets the locator while missing parents inherit global settings', () async {
    final manifest = readerManifest();
    await store.saveLocator(manifest, ReaderLocator(3, .8));
    expect((await store.locator(readerManifest(revision: 'new'))).pageIndex, 0);
    await store.saveOverrides(
      SettingsScope.library,
      'library',
      const ReadingOverrides(mode: ReadingMode.webtoon),
    );
    final noParent = ReaderManifest(
      accountId: manifest.accountId,
      bookId: manifest.bookId,
      revision: manifest.revision,
      title: manifest.title,
      pages: manifest.pages,
    );
    expect((await store.settings(noParent).first).mode, ReadingMode.paged);
  });
  test('invalid spacing and page bounds never persist', () async {
    await expectLater(
      store.saveOverrides(
        SettingsScope.global,
        '',
        const ReadingOverrides(spacing: -1),
      ),
      throwsArgumentError,
    );
    await expectLater(
      store.saveLocator(readerManifest(), ReaderLocator(4)),
      throwsRangeError,
    );
    expect(() => ReaderLocator(0, double.nan), throwsArgumentError);
    expect(
      () => ReadingOverrides.fromJson({'spacing': 65}),
      throwsFormatException,
    );
    expect(await database.select(database.readingPreferences).get(), isEmpty);
  });

  test(
    'v2 migration preserves catalogue and v4 reader state survives reopening',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'inkora-reader-migration-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/metadata.sqlite');
      await database.close();
      final old = AppDatabase(NativeDatabase(file));
      await old
          .into(old.serverProfiles)
          .insert(
            ServerProfilesCompanion.insert(
              id: 'server',
              displayName: 'Fixture',
              baseUrl: 'https://example.test/',
            ),
          );
      await old
          .into(old.catalogueSnapshots)
          .insert(
            CatalogueSnapshotsCompanion.insert(
              accountId: 'reader-account',
              generation: 'published',
              updatedAt: DateTime.utc(2026, 10, 11),
            ),
          );
      for (final table in [
        'offline_settings',
        'download_jobs',
        'download_parts',
        'progress_heads',
        'progress_events',
        'reader_manifests',
        'reader_assets',
        'reader_downloads',
        'reading_preferences',
        'reader_positions',
      ]) {
        await old.customStatement('DROP TABLE $table');
      }
      await old.customStatement('DROP INDEX catalogue_document_books');
      await old.customStatement(
        'ALTER TABLE catalogue_entries DROP COLUMN descriptive_metadata',
      );
      await old.customStatement('PRAGMA user_version = 2');
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      final persisted = ReaderStore(upgraded, 'reader-account');
      expect(
        (await upgraded.select(upgraded.serverProfiles).getSingle()).id,
        'server',
      );
      expect(
        (await upgraded.select(upgraded.catalogueSnapshots).getSingle())
            .generation,
        'published',
      );
      await persisted.saveManifest(readerManifest());
      await persisted.saveLocator(readerManifest(), ReaderLocator(2, .375));
      await persisted.saveOverrides(
        SettingsScope.global,
        '',
        const ReadingOverrides(
          mode: ReadingMode.manga,
          layout: ReadingLayout.doublePage,
        ),
      );
      await persisted.saveOverrides(
        SettingsScope.book,
        'reader-book',
        const ReadingOverrides(mode: ReadingMode.webtoon, spacing: 0),
      );
      await upgraded.close();
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final restored = ReaderStore(reopened, 'reader-account');
        final profile = await restored.overrides(SettingsScope.global, '');
        expect(profile.mode, ReadingMode.manga);
        expect(profile.layout, ReadingLayout.doublePage);
        expect(
          (await restored.manifest('reader-book'))!.revision,
          'revision-a',
        );
        final locator = await restored.locator(readerManifest());
        expect(locator.pageIndex, 2);
        expect(locator.fraction, .375);
        expect(
          (await restored.settings(readerManifest()).first).mode,
          ReadingMode.webtoon,
        );
      } finally {
        await reopened.close();
      }
    },
  );
}
