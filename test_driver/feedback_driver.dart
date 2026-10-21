import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [arguments]) async {
    final root =
        Platform.environment['INKORA_FEEDBACK_ARTIFACTS'] ??
        'artifacts/feedback/screenshots';
    final output = File('$root/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    return true;
  },
);
