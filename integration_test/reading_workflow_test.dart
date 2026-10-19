import '../test/support/settings_qr_fixture.dart';

import 'dart:ui' as ui;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    'Android QR decoder reads a generated settings QR without networking',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final controller = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
      );
      File? image;
      try {
        final transfer = SettingsTransfer(database, 'fixture-account');
        final payload = await legacySettingsQr(transfer);
        final painter = QrPainter(
          data: payload,
          version: QrVersions.auto,
          gapless: true,
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1104, 1104),
          Paint()..color = Colors.white,
        );
        canvas.translate(40, 40);
        painter.paint(canvas, const Size(1024, 1024));
        final picture = recorder.endRecording();
        final qrImage = await picture.toImage(1104, 1104);
        final bytes = await qrImage.toByteData(format: ui.ImageByteFormat.png);
        qrImage.dispose();
        picture.dispose();
        expect(bytes, isNotNull);
        image = File(
          '${(await getTemporaryDirectory()).path}/inkora-settings-verification.png',
        );
        await image.writeAsBytes(bytes!.buffer.asUint8List());
        final capture = await controller.analyzeImage(
          image.path,
          formats: [BarcodeFormat.qrCode],
        );
        expect(capture?.barcodes.any((b) => b.rawValue == payload), true);
        final value = await transfer.inspectQr(
          capture!.barcodes.first.rawValue!,
        );
        expect(value['portable'], true);
      } finally {
        await controller.dispose();
        if (image != null && await image.exists()) await image.delete();
        await database.close();
      }
    },
  );
  testWidgets('Android scanner starts camera and releases it on close', (
    tester,
  ) async {
    final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MobileScanner(controller: controller)),
      ),
    );
    for (var i = 0; i < 40 && !controller.value.isRunning; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(controller.value.isRunning, true);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.stop();
    expect(controller.value.isRunning, false);
    await controller.dispose();
  });
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
