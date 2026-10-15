import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 45),
  responseDataCallback: (data) async {
    final output = File(
      Platform.environment['WEBTOON_REPORT'] ??
          'artifacts/webtoon-investigation/trace.json',
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
  },
);
