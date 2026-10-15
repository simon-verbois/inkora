import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

/// An actual image-heavy PDF, generated in a worker without a bundled asset.
/// Each page has a distinct PDF image object and a searchable page identifier.
Future<int> createLargePdf(
  String path, {
  int pages = 500,
}) => Isolate.run(() async {
  const width = 768, height = 1152;
  final random = Random(15973);
  final pixels = Uint8List(width * height);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = random.nextInt(16) * 17;
  }
  final image = ZLibEncoder(level: 6).convert(pixels);
  final file = await File(path).open(mode: FileMode.write);
  final offsets = List<int>.filled(4 + pages * 3, 0);
  Future<void> text(String value) => file.writeString(value);
  Future<void> object(int id, String value) async {
    offsets[id] = await file.position();
    await text('$id 0 obj\n$value\nendobj\n');
  }

  try {
    await text('%PDF-1.7\n');
    await object(1, '<< /Type /Catalog /Pages 2 0 R >>');
    await object(
      2,
      '<< /Type /Pages /Count $pages /Kids [${List.generate(pages, (i) => '${4 + i * 3} 0 R').join(' ')}] >>',
    );
    await object(3, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    for (var i = 0; i < pages; i++) {
      final id = 4 + i * 3;
      await object(
        id,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $width $height] /Resources << /Font << /F1 3 0 R >> /XObject << /Im0 ${id + 2} 0 R >> >> /Contents ${id + 1} 0 R >>',
      );
      final content =
          'q $width 0 0 $height 0 0 cm /Im0 Do Q\n1 1 1 rg 0 1000 $width 152 re f\n0 0 0 rg BT /F1 24 Tf 30 1100 Td (Inkora large PDF - page ${i + 1}) Tj 0 -40 Td (LANTERN${(i + 1).toString().padLeft(5, '0')}) Tj ET';
      await object(
        id + 1,
        '<< /Length ${utf8.encode(content).length} >>\nstream\n$content\nendstream',
      );
      offsets[id + 2] = await file.position();
      await text(
        '${id + 2} 0 obj\n<< /Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /Length ${image.length} >>\nstream\n',
      );
      await file.writeFrom(image);
      await text('\nendstream\nendobj\n');
    }
    final xref = await file.position();
    await text('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      await text('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    await text(
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
    );
    return await file.position();
  } finally {
    await file.close();
  }
});
