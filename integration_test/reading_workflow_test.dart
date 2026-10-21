import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/core/storage/app_database.dart';
import 'package:inkora/features/settings/data/settings_transfer.dart';

import 'support/ui_fixture_binding.dart';
import '../test/features/settings/reading_workflow_widget_test.dart'
    as journeys;
import '../test/reader/presentation/raster_navigation_test.dart' as raster;

void main() {
  UiFixtureIntegrationBinding();
  journeys.main();
  raster.main();
  testWidgets(
    'Android file picker saves, reopens and cancels a synthetic backup',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Native file backup verification')),
        ),
      );
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final transfer = SettingsTransfer(database, 'fixture-account');
        final bytes = await transfer.export();
        debugPrint('INKORA_FILE_SAVE_READY');
        final uri = await FilePicker.saveFile(
          fileName: 'inkora-verification.json',
          bytes: bytes,
          mimeType: 'application/json',
        );
        expect(uri, isNotNull);
        debugPrint('INKORA_FILE_OPEN_READY');
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        expect(files, hasLength(1));
        final restored = await transfer.inspect(
          await files.single.readAsBytes(),
        );
        expect(restored['account'], 'fixture-account');
        debugPrint('INKORA_FILE_CANCEL_READY');
        final cancelled = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        expect(cancelled, isEmpty);
        debugPrint('INKORA_FILE_ROUNDTRIP_PASSED');
      } finally {
        await database.close();
      }
    },
  );
}
