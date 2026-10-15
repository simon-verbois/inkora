import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Actual 720-pixel-wide, textured RGB strips. Filtering/compression and the
/// pixel loop run in a worker; no 1x1 image disguised by manifest geometry.
Future<Uint8List> tallStripFixture({int height = 7000, int seed = 19}) =>
    Isolate.run(() {
      const width = 720;
      final raw = Uint8List((width * 3 + 1) * height);
      var random = seed;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          random = (random * 1664525 + 1013904223) & 0xffffffff;
          final at = y * (width * 3 + 1) + 1 + x * 3;
          // Panel-like bands and gradients plus compressible texture. No black
          // artwork: absent regions remain distinguishable in visual probes.
          final noise = (random >> 28) & 15;
          raw[at] = 50 + (x ~/ 4 + y ~/ 80 + noise) % 180;
          raw[at + 1] = 60 + (y ~/ 6 + noise) % 170;
          raw[at + 2] = 70 + ((x ^ y) ~/ 8 + noise) % 160;
        }
      }
      final result = BytesBuilder(copy: false)
        ..add([137, 80, 78, 71, 13, 10, 26, 10]);
      void chunk(String type, List<int> bytes) {
        final data = Uint8List(12 + bytes.length);
        final view = ByteData.sublistView(data);
        view.setUint32(0, bytes.length);
        data.setRange(4, 8, type.codeUnits);
        data.setRange(8, 8 + bytes.length, bytes);
        var crc = 0xffffffff;
        for (var i = 4; i < 8 + bytes.length; i++) {
          crc ^= data[i];
          for (var bit = 0; bit < 8; bit++) {
            crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xedb88320 : 0);
          }
        }
        view.setUint32(8 + bytes.length, crc ^ 0xffffffff);
        result.add(data);
      }

      final header = Uint8List(13);
      ByteData.sublistView(header)
        ..setUint32(0, width)
        ..setUint32(4, height);
      header[8] = 8;
      header[9] = 2;
      chunk('IHDR', header);
      chunk('IDAT', zlib.encode(raw));
      chunk('IEND', []);
      return result.takeBytes();
    });
