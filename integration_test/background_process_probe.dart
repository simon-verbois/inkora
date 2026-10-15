// Standalone debug-only entry point for scripts/background_probe.py.
// It never mounts the normal app or writes remote reading progress.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inkora/core/network/komga/komga_client.dart';
import 'package:inkora/core/network/server_endpoint.dart';
import 'package:inkora/features/connection/data/development_login.dart';
import 'package:inkora/offline/application/background_transfer.dart';
import 'package:inkora/reader/data/komga_reader_remote.dart';
import 'package:inkora/reader/data/reader_asset_store.dart';

const probeAccount = 'native-background-probe';
const probeJob =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Native background transfer verification')),
      ),
    ),
  );
  final support = await getApplicationSupportDirectory();
  final folder = Directory('${support.path}/native-background-probe');
  await folder.create(recursive: true);
  final report = File('${folder.path}/report.json');
  final bridge = BackgroundTransfer();
  KomgaClient? client;
  try {
    await bridge.foreground();
    final command = jsonDecode(
      await File('${folder.path}/command.json').readAsString(),
    ) as Map<String, dynamic>;
    if (command['mode'] == 'cleanup') {
      await bridge.cancelAccount(probeAccount);
      await report.writeAsString(jsonEncode({'state': 'cleaned'}), flush: true);
    } else if (command['mode'] == 'prepare') {
      await bridge.cancelAccount(probeAccount);
      final login = await takeDevelopmentLogin(
        File('${support.path}/background-probe-login.json'),
      );
      if (login == null) throw StateError('Probe credentials unavailable');
      client = KomgaClient(ServerEndpoint(login.serverUrl), login.credentials);
      final books = await client.books(size: 1);
      final manifest = await KomgaReaderRemote.loadManifest(
        client,
        probeAccount,
        books.items.first.id,
        CancelToken(),
      );
      final reference = File('${folder.path}/reference.png');
      final image = await client.pageToFile(
        manifest.bookId,
        0,
        reference,
        cancelToken: CancelToken(),
        maximumBytes: maximumEncodedPageBytes,
      );
      final bytes = await reference.readAsBytes();
      validateRaster(bytes, image.mediaType);
      final hash = await rasterChecksum(bytes);
      await File('${folder.path}/expected.json').writeAsString(
        jsonEncode({
          'checksum': hash,
          'length': bytes.length,
          'mediaType': image.mediaType,
        }),
        flush: true,
      );
      await bridge.enqueue(
        [
          for (var page = 0; page < 4; page++)
            {
              'id': '$probeJob-$page',
              'account': probeAccount,
              'job': probeJob,
              'page': page,
              'path': '${folder.path}/$page.native',
              'maximumBytes': maximumEncodedPageBytes,
              'url': client.pageUri(manifest.bookId, 0).toString(),
            },
        ],
        headers: login.credentials.headers,
        wifiOnly: true,
      );
      await report.writeAsString(
        jsonEncode({'state': 'prepared', 'length': bytes.length, 'tasks': 4}),
        flush: true,
      );
    } else {
      final expected = jsonDecode(
        await File('${folder.path}/expected.json').readAsString(),
      ) as Map<String, dynamic>;
      final results = (await bridge.results())
          .where((r) => r['account'] == probeAccount)
          .toList();
      if (results.length != 4) throw StateError('Incomplete background probe');
      for (final result in results) {
        if (result['state'] != 'complete' ||
            result['byteLength'] != expected['length'] ||
            result['checksum'] != expected['checksum']) {
          throw StateError('Invalid native completion');
        }
        final bytes = await File(result['path'] as String).readAsBytes();
        validateRaster(bytes, result['mediaType'] as String);
        if (await rasterChecksum(bytes) != expected['checksum']) {
          throw StateError('Invalid staged integrity');
        }
        await bridge.acknowledge(result['id'] as String);
      }
      await bridge.cancelAccount(probeAccount);
      await report.writeAsString(
        jsonEncode({
          'state': 'verified',
          'tasks': results.length,
          'length': expected['length'],
          'checksum': expected['checksum'],
          'remoteWrites': 0,
        }),
        flush: true,
      );
    }
  } catch (_) {
    await report.writeAsString(jsonEncode({'state': 'failed'}), flush: true);
  } finally {
    client?.close();
  }
}
