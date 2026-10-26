import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_settings.dart';
import 'package:inkora/reader/presentation/ebook_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('paper source is pinned and bounded for offline thumbnail decoding', () {
    final metadata = jsonDecode(
      File('assets/reader/SOURCES.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bytes = File(metadata['asset'] as String).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(bytes.length, metadata['bytes']);
    expect(bytes.length, lessThan(4 * 1024 * 1024));
    expect(sha256.convert(bytes).toString(), metadata['sha256']);
    expect(data.getUint32(16), inInclusiveRange(1, 2048));
    expect(data.getUint32(20), inInclusiveRange(1, 2048));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/reader/paper.png'),
    );
  });
  test('bundled font bytes match pinned upstream provenance', () {
    final source = jsonDecode(
      File('assets/fonts/SOURCES.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final files = source['files'] as List<dynamic>;
    expect(files, hasLength(25));
    for (final file in files.cast<Map<String, dynamic>>()) {
      final bytes = File(file['asset'] as String).readAsBytesSync();
      expect(bytes.length, file['bytes']);
      expect(sha256.convert(bytes).toString(), file['sha256']);
      expect(file['source'], contains('/${source['revision']}/ofl/'));
    }
  });
  test(
    'every named reader font has bundled native faces and its own license',
    () async {
      final bundled = EbookFont.values
          .where((font) => font.previewFamily != null)
          .toList();
      expect(
        ebookFontDeclarations.map((font) => font.name).toList(),
        bundled.map((font) => font.nativeFamily).toList(),
      );
      for (final font in ebookFontDeclarations) {
        for (final face in font.faces) {
          final data = await rootBundle.load(face.asset);
          expect(data.lengthInBytes, greaterThan(10000));
          expect(data.getUint32(0), anyOf(0x00010000, 0x4f54544f));
        }
        if (font.name != 'InkoraBaskerville') {
          expect(
            font.faces
                .map((face) => '${face.weight}-${face.style.name}')
                .toSet(),
            {'400-normal', '400-italic', '700-normal', '700-italic'},
          );
          final license = await rootBundle.loadString(
            'assets/fonts/${font.name}-OFL.txt',
          );
          expect(license.toUpperCase(), contains('SIL OPEN FONT LICENSE'));
          expect(
            File('pubspec.yaml').readAsStringSync(),
            contains('family: ${font.name}'),
          );
        }
      }
      expect(EbookFont.publisher.nativeFamily, isNull);
      expect(EbookFont.serif.nativeFamily, 'serif');
      expect(EbookFont.sansSerif.nativeFamily, 'sans-serif');
    },
  );
}
