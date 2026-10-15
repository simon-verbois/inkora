import '../domain/ebook_locator.dart';

import 'dart:convert';
import 'dart:isolate';

import '../domain/reader_manifest.dart';

/// Top-level worker boundaries capture only values, never repositories or DBs.
Future<String> encodeReaderManifest(ReaderManifest manifest) =>
    Isolate.run(() => jsonEncode(manifest.toJson()));
Future<ReaderManifest> decodeReaderManifest(String payload) => Isolate.run(
  () => ReaderManifest.fromJson(jsonDecode(payload) as Map<String, dynamic>),
);

Future<EbookPositionMap> buildEbookPositionMap(
  List<Map<String, dynamic>> positions,
) => Isolate.run(() => EbookPositionMap(positions));
