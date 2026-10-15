import 'dart:math' as math;

/// User-facing webtoon image quality. Presets trade sharpness against how far
/// ahead strips are decoded; [custom] exposes the three underlying controls.
enum WebtoonQuality { saver, balanced, sharp, custom }

/// Underlying controls behind every preset (and the custom sliders).
final class WebtoonQualityProfile {
  const WebtoonQualityProfile({
    required this.sharpness,
    required this.preloadScreens,
    required this.memoryMiB,
  });

  /// Decode resolution as a fraction of the screen's physical pixels
  /// (never above the source image).
  final double sharpness;

  /// Screens decoded ahead (and kept behind) the visible one.
  final int preloadScreens;

  /// Ceiling for live decoded webtoon images, in MiB.
  final int memoryMiB;

  static const minSharpness = 0.5, maxSharpness = 1.0;
  static const minPreload = 1, maxPreload = 4;
  static const minMemoryMiB = 32, maxMemoryMiB = 128;

  static const saver = WebtoonQualityProfile(
    sharpness: .6,
    preloadScreens: 2,
    memoryMiB: 32,
  );
  static const balanced = WebtoonQualityProfile(
    sharpness: .75,
    preloadScreens: 2,
    memoryMiB: 48,
  );
  static const sharp = WebtoonQualityProfile(
    sharpness: 1,
    preloadScreens: 2,
    memoryMiB: 80,
  );

  static WebtoonQualityProfile preset(WebtoonQuality quality) =>
      switch (quality) {
        WebtoonQuality.saver => saver,
        WebtoonQuality.sharp => sharp,
        WebtoonQuality.balanced || WebtoonQuality.custom => balanced,
      };

  static void validate({double? sharpness, int? preload, int? memoryMiB}) {
    if (sharpness != null &&
        (!sharpness.isFinite ||
            sharpness < minSharpness ||
            sharpness > maxSharpness)) {
      throw const FormatException('Invalid webtoon sharpness');
    }
    if (preload != null && (preload < minPreload || preload > maxPreload)) {
      throw const FormatException('Invalid webtoon preload');
    }
    if (memoryMiB != null &&
        (memoryMiB < minMemoryMiB || memoryMiB > maxMemoryMiB)) {
      throw const FormatException('Invalid webtoon memory');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WebtoonQualityProfile &&
      other.sharpness == sharpness &&
      other.preloadScreens == preloadScreens &&
      other.memoryMiB == memoryMiB;
  @override
  int get hashCode => Object.hash(sharpness, preloadScreens, memoryMiB);
}

/// A profile resolved against the actual viewport. Strips are budgeted by
/// displayed area, so live decoded memory follows the prepared window height
/// rather than strip count; the memory ceiling first shortens preparation,
/// then lowers sharpness, and is never exceeded by design.
final class WebtoonBudget {
  const WebtoonBudget({
    required this.sharpness,
    required this.preloadScreens,
    required this.perScreenBytes,
    required this.memoryBytes,
  });

  final double sharpness;
  final int preloadScreens;
  final int perScreenBytes;
  final int memoryBytes;

  /// A strip taller than this many screens shares one capped allowance.
  static const maxScreensPerStrip = 3;

  /// Include whole decoded strips intersecting both window edges. Long
  /// strips can retain three screens at each edge, not just one; overlooking
  /// that cost makes the later window fit discard all decode lookahead.
  static double residentScreens(
    int preload, {
    double maximumStripScreens = 1,
  }) =>
      1 +
      2 * preload +
      2 *
          math.max(
            1.0,
            math.min(maxScreensPerStrip.toDouble(), maximumStripScreens),
          );

  factory WebtoonBudget.resolve(
    WebtoonQualityProfile profile, {
    required double physicalWidth,
    required double physicalHeight,
    double maximumStripScreens = 1,
  }) {
    final memory = profile.memoryMiB * 1024 * 1024;
    final full =
        math.max(1.0, physicalWidth) * math.max(1.0, physicalHeight) * 4;
    var sharpness = profile.sharpness;
    var preload = profile.preloadScreens;
    while (preload > 1 &&
        full *
                sharpness *
                sharpness *
                residentScreens(
                  preload,
                  maximumStripScreens: maximumStripScreens,
                ) >
            memory) {
      preload--;
    }
    final fit = math.sqrt(
      memory /
          (full *
              residentScreens(
                preload,
                maximumStripScreens: maximumStripScreens,
              )),
    );
    sharpness = math.max(.25, math.min(sharpness, fit));
    return WebtoonBudget(
      sharpness: sharpness,
      preloadScreens: preload,
      perScreenBytes: math.max(4, (full * sharpness * sharpness).floor()),
      memoryBytes: memory,
    );
  }
}
