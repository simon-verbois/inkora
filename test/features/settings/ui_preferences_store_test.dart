import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/core/images/image_enhancement.dart';

void main() {
  test(
    'system theme defaults validate families and retain legacy fixed themes',
    () {
      for (final invalid in [null, 'unknown', 'system', 42]) {
        final value = UiPreferences.fromJson({
          'appearance': 'ocean',
          'systemLightTheme': invalid,
          'systemDarkTheme': invalid,
        });
        expect(value.appearance, AppAppearance.ocean);
        expect(value.lightTheme, AppAppearance.light);
        expect(value.darkTheme, AppAppearance.dark);
      }
      final invalid = UiPreferences.fromJson({
        'systemLightTheme': 'plum',
        'systemDarkTheme': 'pearl',
      });
      expect(invalid.lightTheme, AppAppearance.light);
      expect(invalid.darkTheme, AppAppearance.dark);
      for (final light in AppAppearance.values.where((a) => a.isLight)) {
        for (final dark in AppAppearance.values.where((a) => a.isDark)) {
          final original = UiPreferences(
            systemLightTheme: light,
            systemDarkTheme: dark,
            locale: 'fr',
            panelOpacity: .96,
          );
          final roundTrip = UiPreferences.fromJson(
            original.copyWith(density: CatalogueDensity.compact).toJson(),
          );
          expect(roundTrip.lightTheme, light);
          expect(roundTrip.darkTheme, dark);
          expect(roundTrip.appearance, AppAppearance.system);
          expect(roundTrip.locale, 'fr');
          expect(roundTrip.panelOpacity, .96);
          expect(roundTrip.density, CatalogueDensity.compact);
        }
      }
    },
  );

  test('new defaults use balanced enhancement and 94 percent without replacing saved choices', () {
    const fresh = UiPreferences();
    expect(fresh.panelOpacity, .94);
    expect(fresh.imageEnhancement, ImageEnhancement.balanced);
    expect(
      UiPreferences.fromJson({}).imageEnhancement,
      ImageEnhancement.balanced,
    );
    final explicit = UiPreferences.fromJson({
      'imageEnhancement': 'off',
      'panelOpacity': 1,
    });
    expect(explicit.imageEnhancement, ImageEnhancement.off);
    expect(explicit.panelOpacity, 1);
  });
  test(
    'legacy and malformed overlay values retain usable bounded preferences',
    () {
      expect(UiPreferences.fromJson({}).floatingNavigation, isTrue);
      expect(UiPreferences.fromJson({}).panelOpacity, .94);
      for (final value in [double.nan, double.infinity, 'broken', null]) {
        expect(
          UiPreferences.fromJson({'panelOpacity': value}).panelOpacity,
          .94,
        );
      }
      expect(UiPreferences.fromJson({'panelOpacity': 0}).panelOpacity, .88);
      expect(UiPreferences.fromJson({'panelOpacity': 2}).panelOpacity, 1);
    },
  );
  test(
    'discovery writes do not re-emit unchanged appearance preferences',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = UiPreferencesStore(database);
      await store.save(const UiPreferences(appearance: AppAppearance.light));
      final appearances = <AppAppearance>[];
      final first = Completer<void>();
      final changed = Completer<void>();
      final subscription = store.watch().listen((value) {
        appearances.add(value.appearance);
        if (!first.isCompleted) first.complete();
        if (value.appearance == AppAppearance.dark && !changed.isCompleted) {
          changed.complete();
        }
      });
      addTearDown(subscription.cancel);
      await first.future;
      await database
          .into(database.appPreferences)
          .insert(
            AppPreferencesCompanion.insert(
              key: 'discovery:account',
              payload: '{}',
            ),
          );
      // Wait for a real table notification so the unchanged UI query also runs.
      await database
          .select(database.appPreferences)
          .watch()
          .firstWhere(
            (rows) => rows.any((row) => row.key == 'discovery:account'),
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(appearances, [AppAppearance.light]);
      await store.save(const UiPreferences(appearance: AppAppearance.dark));
      await changed.future;
      expect(appearances, [AppAppearance.light, AppAppearance.dark]);
    },
  );
  test('appearance persists across reopen and v4 upgrade preserves existing records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'inkora-ui-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/metadata.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    await database
        .into(database.serverProfiles)
        .insert(
          ServerProfilesCompanion.insert(
            id: 'existing',
            displayName: 'Personal',
            baseUrl: 'https://example.test/',
          ),
        );
    await database.customStatement(
      "INSERT INTO reader_positions (account_id,book_id,revision,page_index,fraction) VALUES ('account', 'book', 'revision', 2, 0.5)",
    );
    await database.customStatement('DROP TABLE app_preferences');
    await database.customStatement('DROP TABLE resume_snapshots');
    await database.customStatement('DROP INDEX catalogue_document_books');
    await database.customStatement(
      'ALTER TABLE catalogue_entries DROP COLUMN descriptive_metadata',
    );
    await database.customStatement('PRAGMA user_version=4');
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    final store = UiPreferencesStore(database);
    expect((await store.watch().first).appearance, AppAppearance.system);
    expect(
      (await database.select(database.serverProfiles).getSingle()).id,
      'existing',
    );
    expect(
      (await database.select(database.readerPositions).getSingle()).fraction,
      .5,
    );
    await store.save(
      const UiPreferences(
        appearance: AppAppearance.amoled,
        density: CatalogueDensity.compact,
        textScale: 1.3,
        reduceMotion: true,
        floatingNavigation: false,
        panelOpacity: .9,
        imageEnhancement: ImageEnhancement.balanced,
      ),
    );
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    try {
      final restored = await UiPreferencesStore(database).watch().first;
      expect(restored.appearance, AppAppearance.amoled);
      expect(restored.density, CatalogueDensity.compact);
      expect(restored.textScale, 1.3);
      expect(restored.reduceMotion, isTrue);
      expect(restored.floatingNavigation, isFalse);
      expect(restored.panelOpacity, .9);
      expect(restored.copyWith(locale: 'fr').panelOpacity, .9);
      expect(restored.imageEnhancement, ImageEnhancement.balanced);
      expect(
        restored.copyWith(locale: 'fr').imageEnhancement,
        ImageEnhancement.balanced,
      );
    } finally {
      await database.close();
    }
  });

  test(
    'corrupt and future preference fields fall back to usable defaults',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.appPreferences)
          .insert(AppPreferencesCompanion.insert(key: 'ui', payload: 'broken'));
      final store = UiPreferencesStore(database);
      expect((await store.watch().first).appearance, AppAppearance.system);
      final preferences = UiPreferences.fromJson({
        'appearance': 'future-theme',
        'textScale': 20,
        'imageEnhancement': 'future-enhancement',
      });
      expect(preferences.textScale, 1);
      expect(preferences.appearance, AppAppearance.system);
      expect(preferences.imageEnhancement, ImageEnhancement.balanced);
      expect(
        UiPreferences.fromJson({}).imageEnhancement,
        ImageEnhancement.balanced,
      );
    },
  );
}
