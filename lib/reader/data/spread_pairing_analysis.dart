import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/page_source.dart';
import '../domain/reader_manifest.dart';
import '../domain/spread_pairing.dart';
import 'reader_asset_store.dart';

typedef PairingSampleLoader = Future<PageEdgeSample?> Function(
  int index,
  CancellationSignal cancellation,
);

/// One opening-time decision, bounded independently of foreground page work.
/// No remote transport, prefetch admission, decoded cache or per-turn work.
Future<SpreadPairingAnalysis> analyzeSpreadPairing(
  ReaderManifest manifest, {
  required bool rightToLeft,
  required CancellationSignal cancellation,
  required PairingSampleLoader sample,
  Duration deadline = const Duration(milliseconds: 120),
}) async {
  final geometry = SpreadPairingAnalyzer.dimensions(manifest.pages);
  var result = geometry;
  if (geometry == null && !cancellation.isCancelled) {
    final work = CancellationController();
    unawaited(cancellation.whenCancelled.then((_) => work.cancel()));
    try {
      final samples = <int, PageEdgeSample>{};
      // Compare the two opening parities using at most eight portrait files.
      // Stop before a wide/illustration anchor, where file parity may differ.
      await (() async {
        for (var i = 0; i < manifest.pages.length && i < 8; i++) {
          if (work.isCancelled || manifest.pages[i].aspectRatio >= 1) break;
          final edge = await sample(i, work);
          if (work.isCancelled) return;
          if (edge != null) samples[i] = edge;
        }
      })().timeout(deadline);
      result = SpreadPairingAnalyzer.visual(samples, rightToLeft: rightToLeft);
    } catch (_) {
      // Optional missing/corrupt local evidence must not block reading.
    } finally {
      work.cancel();
    }
  }
  return SpreadPairingAnalysis(
    revision: manifest.revision,
    rightToLeft: rightToLeft,
    shifted: result,
  );
}

/// At most 8 MiB encoded across eight reads; 32×64 RGBA (8 KiB) per codec,
/// sequentially disposed. Missing local pages never fall through to network.
final class LocalPairingSamples {
  LocalPairingSamples(this.assets, this.manifest);
  final ReaderAssetStore assets;
  final ReaderManifest manifest;
  var _remaining = 8 * 1024 * 1024;

  Future<PageEdgeSample?> read(
    int index,
    CancellationSignal cancellation,
  ) async {
    if (cancellation.isCancelled || _remaining <= 0) return null;
    final limit = _remaining.clamp(0, 2 * 1024 * 1024);
    final page = await assets.readForPairing(
      manifest.key(index),
      cancellation,
      maximumBytes: limit,
    );
    if (page == null || cancellation.isCancelled) return null;
    _remaining -= page.bytes.length;
    final codec = await ui.instantiateImageCodec(
      page.bytes,
      targetWidth: 32,
      targetHeight: 64,
      allowUpscaling: false,
    );
    try {
      if (cancellation.isCancelled) return null;
      final frame = await codec.getNextFrame();
      try {
        if (cancellation.isCancelled) return null;
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (pixels == null ||
            frame.image.height != 64 ||
            frame.image.width < 4) {
          return null;
        }
        final left = Uint8List(64), right = Uint8List(64);
        final width = frame.image.width;
        for (var y = 0; y < 64; y++) {
          int luminance(int x) {
            final offset = (y * width + x) * 4;
            // White-composite transparent margins; do not invent black joins.
            final alpha = pixels.getUint8(offset + 3) / 255;
            final gray =
                (.2126 * pixels.getUint8(offset) +
                .7152 * pixels.getUint8(offset + 1) +
                .0722 * pixels.getUint8(offset + 2));
            return (gray * alpha + 255 * (1 - alpha)).round();
          }

          left[y] = luminance(1);
          right[y] = luminance(width - 2);
        }
        return PageEdgeSample(left, right);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}
