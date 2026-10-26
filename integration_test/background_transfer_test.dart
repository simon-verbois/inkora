import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/core/network/http_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('explicit HTTP reaches a loopback server on the native app', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = createHttpClient(
      ServerEndpoint('http://127.0.0.1:${server.port}/komga'),
    );
    server.listen((request) async {
      expect(request.uri.path, '/komga/api/v2/users/me');
      request.response.write('native-http-fixture');
      await request.response.close();
    });
    try {
      expect(
        (await client.get<String>('api/v2/users/me')).data,
        'native-http-fixture',
      );
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
  for (final scheme in ['https', 'http']) {
    testWidgets(
      'native $scheme queue rejects traversal, deduplicates tasks and isolates cancellation',
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
          'url': '$scheme://example.test/private-page',
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
}
