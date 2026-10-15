import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/offline/application/background_transfer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native queue rejects traversal, deduplicates tasks and isolates cancellation',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final bridge = BackgroundTransfer();
      const account = 'native-transfer-fixture';
      const job =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await bridge.foreground();
      await bridge.cancelAccount(account);
      final task = <String, Object?>{
        'id': '$job-0',
        'job': job,
        'account': account,
        'page': 0,
        'path': '${support.path}/native-transfer-fixture/0.native',
        'url': 'https://example.test/private-page',
        'maximumBytes': 1024,
      };
      try {
        await expectLater(
          bridge.enqueue(
            [
              {...task, 'path': '/tmp/traversal'},
            ],
            headers: Platform.isAndroid
                ? {'X-API-Key': 'non-secret-native-fixture'}
                : {
                    'Authorization':
                        'Basic bmF0aXZlOm5vbi1zZWNyZXQtbmF0aXZlLWZpeHR1cmU=',
                  },
            wifiOnly: true,
          ),
          throwsA(isA<PlatformException>()),
        );
        await bridge.enqueue(
          [task, task],
          headers: Platform.isAndroid
              ? {'X-API-Key': 'non-secret-native-fixture'}
              : {
                  'Authorization':
                      'Basic bmF0aXZlOm5vbi1zZWNyZXQtbmF0aXZlLWZpeHR1cmU=',
                },
          wifiOnly: true,
        );
        final queued = await BackgroundTransfer.channel
            .invokeMapMethod<String, dynamic>('status');
        expect(queued!['count'], 1);
        final metadata = File(
          '${support.path}/background-transfers.${Platform.isAndroid ? 'enc' : 'json'}',
        );
        final encrypted = await metadata.readAsBytes();
        expect(
          String.fromCharCodes(encrypted),
          isNot(contains('non-secret-native-fixture')),
        );
        await bridge.cancelAccount('other-account');
        expect(
          (await BackgroundTransfer.channel.invokeMapMethod<String, dynamic>(
            'status',
          ))!['count'],
          1,
        );
        await bridge.cancelAccount(account);
        expect(
          (await BackgroundTransfer.channel.invokeMapMethod<String, dynamic>(
            'status',
          ))!['count'],
          0,
        );
        if (Platform.isAndroid) expect(await metadata.exists(), isFalse);
      } finally {
        await bridge.cancelAccount(account);
      }
    },
  );
}
