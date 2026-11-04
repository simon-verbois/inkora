import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/app/l10n/app_strings.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/domain/metadata_visibility.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/presentation/visible_metadata.dart';

import '../../support/ui_harness.dart';
import '../../support/catalogue_fakes.dart';
import '../../support/onboarding_visuals.dart';

const metadata = CatalogueMetadata(
  genres: ['Fantasy'],
  tags: ['Fixture tag'],
  language: 'fr',
  publisher: 'Fixture Press',
  releaseDate: '2024-03-01',
  isbn: '9780000000002',
  status: 'ENDED',
  mediaType: 'application/x-cbz',
  ageRating: 16,
  readingDirection: 'LEFT_TO_RIGHT',
  links: [CatalogueLink('Fixture website', 'https://example.test')],
  authors: [
    CatalogueAuthor('Writer Name', 'writer'),
    CatalogueAuthor('Artist Name', 'penciller'),
    CatalogueAuthor('Cover Name', 'cover'),
    CatalogueAuthor('Other Name', 'future-role'),
  ],
);

void main() {
  setUpAll(loadOnboardingFonts);
  test(
    'defaults hide only tags and language, retaining legacy explicit tags',
    () {
      for (final preferences in [
        const UiPreferences(),
        UiPreferences.fromJson({}),
      ]) {
        for (final field in MetadataField.values) {
          expect(
            preferences.metadataVisibility.shows(field),
            field != MetadataField.tags && field != MetadataField.language,
          );
        }
      }
      expect(
        UiPreferences.fromJson({'hideTags': false}).metadataVisibility
            .shows(MetadataField.tags),
        isTrue,
      );
      expect(
        UiPreferences.fromJson({
          'hiddenMetadata': [1],
        }).metadataVisibility.shows(MetadataField.language),
        isFalse,
      );
      final all = MetadataVisibility.fromJson(
        MetadataField.values.map((e) => e.name).toList(),
      );
      final saved = const UiPreferences().copyWith(
        metadata: all,
        hideTags: false,
      );
      final restored = UiPreferences.fromJson(saved.toJson());
      expect(restored.metadataVisibility, saved.metadataVisibility);
      expect(
        restored.copyWith(locale: 'fr').metadataVisibility,
        saved.metadataVisibility,
      );
      expect(
        MetadataVisibility.fromJson(['future-field'])
            .shows(MetadataField.genres),
        isTrue,
      );
    },
  );
  test('each metadata field is a display-only projection and credits obey the master switch', () {
    final original = metadata.toJson();
    const allShown = MetadataVisibility(hiddenMask: 0);
    for (final field in MetadataField.values) {
      final visibility = allShown.withVisible(field, false);
      final view = visibleMetadata(metadata, visibility);
      expect(metadata.toJson(), original);
      expect(visibility.shows(field), isFalse);
      if (field == MetadataField.authors) {
        expect(view.authors, isEmpty);
      }
      if (field == MetadataField.writers) {
        expect(view.authors.map((a) => a.name), isNot(contains('Writer Name')));
      }
      if (field == MetadataField.pencillers) {
        expect(view.authors.map((a) => a.name), isNot(contains('Artist Name')));
      }
      if (field == MetadataField.coverArtists) {
        expect(view.authors.map((a) => a.name), isNot(contains('Cover Name')));
      }
    }
    final none = MetadataVisibility.fromJson(
      MetadataField.values.map((e) => e.name).toList(),
    ).withVisible(MetadataField.tags, false);
    final view = visibleMetadata(metadata, none);
    expect(view.authors, isEmpty);
    expect(view.genres, isEmpty);
    expect(view.tags, isEmpty);
    expect(view.links, isEmpty);
    expect(view.publisher, isEmpty);
    expect(view.language, isEmpty);
    expect(view.isbn, isEmpty);
    expect(view.releaseDate, isEmpty);
    expect(view.mediaType, isEmpty);
    expect(view.readingDirection, isEmpty);
    expect(view.status, isEmpty);
    expect(view.ageRating, isNull);
  });
  for (final locale in AppStrings.supportedLocales) {
    testWidgets(
      'metadata controls remain readable and persistent in ${locale.languageCode}/200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(
          tester,
          preferences: UiPreferences(locale: locale.languageCode),
        );
        addTearDown(() => harness.close(tester));
        const capture = Key('metadata-capture');
        await harness.mount(tester, textScale: 2, captureKey: capture);
        harness.container.read(routerProvider).go('/settings/appearance');
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('metadata-language'));
        await tester.scrollUntilVisible(field, 300);
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings(locale.languageCode).text('Visible metadata')),
          findsOneWidget,
        );
        if (locale.languageCode == 'fr') {
          await tester.ensureVisible(
            find.text(AppStrings('fr').text('Visible metadata')),
          );
          await tester.pumpAndSettle();
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'surface-followup-metadata-heading-320-fr',
          );
        }
        expect(tester.widget<SwitchListTile>(field).value, isFalse);
        await tester.tap(field);
        await tester.pumpAndSettle();
        final tags = find.byKey(const Key('hide-tags'));
        await tester.ensureVisible(tags);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(tags).value, isFalse);
        await tester.tap(tags);
        await tester.pumpAndSettle();
        final saved = (await tester.runAsync(
          () => UiPreferencesStore(harness.database).watch().first,
        ))!;
        expect(saved.metadataVisibility.shows(MetadataField.language), isTrue);
        expect(saved.hideTags, isFalse);
        for (final name in ['coverArtists', 'books']) {
          final control = find.byKey(Key('metadata-$name'));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget);
          expect(tester.getSize(control).width, lessThanOrEqualTo(320));
        }
        if (locale.languageCode == 'fr') {
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'surface-followup-metadata-320-fr',
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.platformDispatcher.textScaleFactorTestValue = 1;
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(AppStrings('fr').text('Visible metadata')),
            -300,
          );
          await tester.ensureVisible(
            find.text(AppStrings('fr').text('Visible metadata')),
          );
          await tester.pumpAndSettle();
          await captureOnboarding(
            tester,
            find.byKey(capture),
            'surface-followup-metadata-heading-390-fr',
          );
        }
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
  for (final kind in [CatalogueKind.series, CatalogueKind.book]) {
    testWidgets(
      'hidden metadata disappears from $kind hero and facts without changing catalogue records',
      (tester) async {
        final harness = await UiHarness.create(
          tester,
          catalogue: [
            const CatalogueItem(
              kind: CatalogueKind.library,
              id: 'library-a',
              title: 'Library',
            ),
            CatalogueItem(
              kind: kind,
              id: 'series-a',
              libraryId: 'library-a',
              title: 'Series',
              summary: 'Fixture synopsis',
              metadata: metadata,
            ),
          ],
        );
        addTearDown(() => harness.close(tester));
        await harness.mount(tester);
        final router = harness.container.read(routerProvider);
        router.go('/catalogue/${kind.name}/series-a');
        await tester.pumpAndSettle();
        expect(find.text('fr'), findsNothing);
        expect(find.text('Fixture tag'), findsNothing);
        expect(find.text('Fantasy'), findsWidgets);
        final requests =
            (harness.repository.remote as FakeCatalogueRemote).calls;
        await tester.runAsync(
          () => UiPreferencesStore(harness.database).update(
            (p) => p.copyWith(
              metadata: p.metadata
                  .withVisible(MetadataField.language, true)
                  .withVisible(MetadataField.writers, false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('fr'), findsOneWidget);
        expect(find.textContaining('Writer Name'), findsNothing);
        expect(find.textContaining('Artist Name'), findsWidgets);

        await tester.runAsync(
          () => UiPreferencesStore(harness.database).update(
            (p) => p.copyWith(
              metadata: MetadataVisibility.fromJson(
                MetadataField.values.map((e) => e.name).toList(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final text in [
          'Fantasy',
          'Writer Name',
          'Artist Name',
          'Fixture Press',
          'Fixture synopsis',
          'Publication details',
          'Links',
        ]) {
          expect(find.text(text), findsNothing);
        }
        expect(find.text('Series'), findsWidgets);
        final raw = (await tester.runAsync(
          () => harness.repository.store.item(kind, 'series-a').first,
        ))!;
        expect(raw.metadata.toJson(), metadata.toJson());
        expect(
          (harness.repository.remote as FakeCatalogueRemote).calls,
          requests,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
