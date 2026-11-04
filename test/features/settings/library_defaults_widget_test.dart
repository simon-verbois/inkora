import '../../support/reader_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/reader/data/reader_store.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

import '../../support/ui_harness.dart';

void main() {
  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(1024, 768), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets(
      'library defaults select, persist, apply without reset at $size/$scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await UiHarness.create(tester);
        addTearDown(() => harness.close(tester));
        await harness.mount(tester, textScale: scale);
        final router = harness.container.read(routerProvider);
        router.go('/settings');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Reading profiles'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reading profiles'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Manga shelf'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Manga shelf'), findsOneWidget);
        expect(find.text('Graphic novels'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Manga shelf'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manga shelf'));
        await tester.pumpAndSettle();
        expect(find.text('Inherit'), findsNothing);
        expect(find.text('Preference inheritance'), findsNothing);
        expect(find.text('Comics'), findsOneWidget);
        await chooseReaderPreference(tester, 'reader-choice-mode-manga');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await chooseReaderPreference(tester, 'reader-choice-fit-content');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await chooseReaderPreference(
          tester,
          'reader-choice-spreadPairing-unshifted',
        );
        final offsetRow = (await tester.runAsync(
          () => harness.database
              .select(harness.database.readingPreferences)
              .getSingle(),
        ))!;
        final offsetStore = ReaderStore(harness.database, offsetRow.accountId);
        final manga = (await tester.runAsync(
          () => offsetStore.overrides(SettingsScope.library, 'library-a'),
        ))!;
        expect(
          manga.fit,
          isNull,
          reason: 'The selected default needs no redundant override',
        );
        expect(ReadingSettings.resolve([manga]).fit, ReadingFit.content);
        expect(
          (await tester.runAsync(
            () => offsetStore.overrides(SettingsScope.library, 'library-a'),
          ))!.spreadPairing,
          SpreadPairing.unshifted,
        );
        await chooseReaderPreference(tester, 'reader-choice-mode-webtoon');
        // Applied live: no Save; Back returns to the library list.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Save'), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        final row = await tester.runAsync(
          () => harness.database
              .select(harness.database.readingPreferences)
              .getSingle(),
        );
        final store = ReaderStore(harness.database, row!.accountId);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.library, 'library-a'),
          ))!.spreadOffset,
          isNull,
          reason: 'Changing profile clears local pairing',
        );
        final manifest = ReaderManifest(
          accountId: row.accountId,
          bookId: 'new-volume',
          revision: 'revision',
          title: 'New volume',
          libraryId: 'library-a',
          pages: [PageDimensions(400, 1200)],
        );
        final settings = (await tester.runAsync(
          () => store.settings(manifest).first,
        ))!;
        expect(settings.mode, ReadingMode.webtoon);
        expect(settings.fit, ReadingFit.comfort);
        expect(
          (await tester.runAsync(
            () => store.overrides(SettingsScope.library, 'library-b'),
          ))!.mode,
          isNull,
        );
        expect(find.text('Webtoon'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Manga shelf'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manga shelf'));
        await tester.pumpAndSettle();
        expect(find.text('Webtoon'), findsOneWidget);
        expect(find.byKey(const Key('reader-settings-menu')), findsNothing);
        expect(
          (await tester.runAsync(() => store.settings(manifest).first))!.mode,
          ReadingMode.webtoon,
        );
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
