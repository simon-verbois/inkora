import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/features/settings/presentation/library_defaults_screen.dart';

import 'package:inkora/features/library/domain/catalogue.dart';

import '../../support/ui_harness.dart';
import '../../support/catalogue_fakes.dart';

void main() {
  for (final failsFirst in [false, true]) {
    testWidgets(
      'first setup waits for a slow catalogue and retries errors ($failsFirst)',
      (tester) async {
        final harness = await UiHarness.create(
          tester,
          refreshCatalogue: false,
          preferences: const UiPreferences(locale: 'en', setupStep: 4),
        );
        addTearDown(() => harness.close(tester));
        final remote = harness.repository.remote as FakeCatalogueRemote;
        final response = Completer<void>();
        remote.hold = response;
        if (failsFirst) remote.failKind = CatalogueKind.library;
        final refresh = harness.repository.refresh();
        await tester.runAsync(
          () =>
              UiPreferencesStore(harness.database)
                  .update((p) => p.copyWith(setupCompleted: false)),
        );
        await harness.mount(tester, settle: false);
        for (var turn = 0; turn < 6; turn++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.byType(LibraryDefaultsScreen), findsOneWidget);
        expect(find.text('No saved libraries'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.runAsync(() async {
          response.complete();
          await refresh;
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        if (failsFirst) {
          expect(find.text('Library defaults unavailable'), findsOneWidget);
          remote.failKind = null;
          await tester.runAsync(() async {
            await tester.tap(find.text('Retry'));
            await Future<void>.delayed(const Duration(milliseconds: 80));
          });
          for (var turn = 0; turn < 6; turn++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
        }
        expect(find.text('Manga shelf'), findsOneWidget);
        expect(find.text('No saved libraries'), findsNothing);
        expect(tester.takeException(), isNull);
        await harness.close(tester);
      },
    );
  }
}
