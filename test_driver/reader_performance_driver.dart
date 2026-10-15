import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 65),
  writeResponseOnFailure: true,
  responseDataCallback: (data) => writeResponseData(
    data,
    destinationDirectory:
        Platform.environment['INKORA_BENCH_OUTPUT'] ?? 'artifacts/performance',
    testOutputFilename: 'reader',
  ),
);
