import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/domain/gesture_zones.dart';

void main() {
  test('retired preferred-hand input is ignored on import', () {
    final value = UiPreferences.fromJson({'leftHanded': true});
    expect(value.toJson().containsKey('leftHanded'), isFalse);
  });

  test(
    'version two setup resumes configuration after inserting the welcome page',
    () {
      for (var old = 0; old <= 7; old++) {
        final value = UiPreferences.fromJson({
          'setupVersion': 2,
          'setupStep': old,
        });
        expect(value.setupStep, const [1, 1, 1, 2, 3, 5, 6, 7][old]);
        expect(
          UiPreferences.fromJson(value.toJson()).setupStep,
          value.setupStep,
        );
      }
    },
  );
  test('legacy setup resumes at the corresponding section in version six', () {
    const mapping = [1, 1, 2, 2, 3, 5, 6, 6, 7];
    for (var old = 0; old < mapping.length; old++) {
      final restored = UiPreferences.fromJson({
        'setupStep': old,
        'locale': 'fr',
        'setupCompleted': true,
      });
      expect(restored.setupStep, mapping[old]);
      expect(restored.locale, 'fr');
      expect(restored.setupCompleted, true);
      expect(UiPreferences.fromJson(restored.toJson()).setupStep, mapping[old]);
    }
    expect(
      UiPreferences.fromJson({'setupVersion': 2, 'setupStep': 99}).setupStep,
      7,
    );
    expect(UiPreferences.fromJson({'setupStep': -1}).setupStep, 1);
  });
  test(
    'version three setup retains configuration and maps review to completion',
    () {
      const mapping = [1, 1, 1, 2, 3, 4, 5, 6, 7];
      for (var old = 0; old < mapping.length; old++) {
        for (final completed in [false, true]) {
          final restored = UiPreferences.fromJson({
            'setupVersion': 3,
            'setupStep': old,
            'setupCompleted': completed,
            'locale': 'fr',
          });
          expect(restored.setupStep, mapping[old]);
          expect(restored.setupCompleted, completed);
          expect(restored.locale, 'fr');
          expect(
            UiPreferences.fromJson(restored.toJson()).setupStep,
            mapping[old],
          );
        }
      }
    },
  );
  test('version four inserts welcome without resetting configuration', () {
    for (var step = 0; step < 8; step++) {
      final restored = UiPreferences.fromJson({
        'setupVersion': 4,
        'setupStep': step,
        'locale': 'de',
        'setupCompleted': true,
      });
      expect(restored.setupStep, step.clamp(1, 7));
      expect(restored.locale, 'de');
      expect(restored.setupCompleted, isTrue);
      expect(
        UiPreferences.fromJson(restored.toJson()).setupStep,
        step.clamp(1, 7),
      );
    }
  });
  test(
    'version five drops Language without losing setup position or locale',
    () {
      const mapping = [0, 1, 1, 2, 3, 4, 5, 6, 7];
      for (var step = 0; step < mapping.length; step++) {
        for (final completed in [false, true]) {
          final restored = UiPreferences.fromJson({
            'setupVersion': 5,
            'setupStep': step,
            'locale': 'fr',
            'setupCompleted': completed,
          });
          expect(restored.setupStep, mapping[step]);
          expect(restored.locale, 'fr');
          expect(restored.setupCompleted, completed);
          expect(restored.toJson()['setupVersion'], 6);
          expect(
            UiPreferences.fromJson(restored.toJson()).setupStep,
            mapping[step],
          );
        }
      }
      for (var step = 0; step < 8; step++) {
        final current = UiPreferences(setupStep: step, locale: 'de');
        expect(UiPreferences.fromJson(current.toJson()).setupStep, step);
        expect(UiPreferences.fromJson(current.toJson()).locale, 'de');
      }
    },
  );
  test('settings round trip and identical saves emit once', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = UiPreferencesStore(database);
    final value = const UiPreferences(
      locale: 'fr',
      setupCompleted: true,
      setupStep: 7,
      gestures: GestureZones(preset: GesturePreset.custom, left: 40, right: 24),
    );
    await store.save(value);
    var emissions = 0;
    final ready = Completer<void>();
    final subscription = store.watch().listen((_) {
      emissions++;
      if (!ready.isCompleted) ready.complete();
    });
    await ready.future;
    await store.save(value);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions, 1);
    final loaded = await store.watch().first;
    expect(loaded.locale, 'fr');
    expect(loaded.setupCompleted, true);
    expect(loaded.gestures, value.gestures);
    await subscription.cancel();
  });
  test('legacy and malformed settings adopt safe gesture defaults', () {
    expect(UiPreferences.fromJson({}).gestures, const GestureZones());
    expect(
      GestureZones.fromJson({'left': -1, 'right': double.infinity}).left,
      16,
    );
    expect(
      GestureZones.forPreset(GesturePreset.systemNavigation).showSystemBars,
      true,
    );
    expect(
      GestureZones.forPreset(GesturePreset.systemNavigation)
          .copyWith(left: 48)
          .showSystemBars,
      true,
    );
  });
  test('concurrent preference changes preserve independent fields', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = UiPreferencesStore(database);
    await Future.wait([
      store.update((current) => current.copyWith(locale: 'fr')),
      store.update((current) => current.copyWith(setupStep: 3)),
      store.update(
        (current) => current.copyWith(appearance: AppAppearance.dark),
      ),
    ]);
    final saved = await store.watch().first;
    expect(saved.locale, 'fr');
    expect(saved.setupStep, 3);
    expect(saved.appearance, AppAppearance.dark);
  });
}
