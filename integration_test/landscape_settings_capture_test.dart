import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inkora/app/router.dart';
import 'package:inkora/features/settings/data/ui_preferences_store.dart';
import 'package:inkora/features/settings/domain/ui_preferences.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reader_settings_sheet.dart';

import '../test/support/ui_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive
    ..shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'physical landscape settings, keyboard, rotation, edge Back and setup visuals',
    (tester) async {
      final harness = await UiHarness.create(
        tester,
        preferences: const UiPreferences(
          locale: 'fr',
          appearance: AppAppearance.light,
        ),
      );
      addTearDown(() => harness.close(tester));
      await harness.mount(tester);
      final router = harness.container.read(routerProvider);
      router.go('/settings/appearance');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
      debugPrint('LANDSCAPE_CAPTURE_READY: appearance');
      await Future<void>.delayed(const Duration(seconds: 5));
      router.go('/settings/quality');
      await tester.pumpAndSettle();
      final editor = tester.state<ReaderSettingsSheetState>(
        find.byType(ReaderSettingsSheet),
      );
      final sampler = find.byType(DropdownButtonFormField<ImageSampling>).first;
      await tester.ensureVisible(sampler);
      await tester.tap(sampler);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus proche voisin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-sidebar-search')));
      await tester.pump(const Duration(milliseconds: 700));
      debugPrint('LANDSCAPE_CAPTURE_READY: keyboard');
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      // Shell layout already consumes IME insets before the editor sees them.
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      expect(find.text('Enregistrer').hitTestable(), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 800));
      debugPrint('LANDSCAPE_ROTATE_READY: portrait');
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-sidebar')), findsNothing);
      expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
      expect(
        tester
            .widget<DropdownButtonFormField<ImageSampling>>(sampler)
            .initialValue,
        ImageSampling.nearest,
      );
      debugPrint('LANDSCAPE_ROTATE_READY: landscape');
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
      expect(tester.state(find.byType(ReaderSettingsSheet)), same(editor));
      debugPrint('LANDSCAPE_EDGE_READY');
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      router.push('/setup?edit=true');
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('setup-next')));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () =>
            UiPreferencesStore(harness.database)
                .update((p) => p.copyWith(appearance: AppAppearance.dark)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-sidebar')), findsOneWidget);
      debugPrint('LANDSCAPE_CAPTURE_READY: setup');
      await Future<void>.delayed(const Duration(seconds: 5));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('setup-next')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Manga shelf'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderSettingsSheet), findsOneWidget);
      debugPrint('LANDSCAPE_CAPTURE_READY: library');
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    },
  );
}
