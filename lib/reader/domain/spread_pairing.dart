import 'dart:typed_data';

import 'reader_manifest.dart';

enum SpreadPairing { automatic, unshifted, shifted }

/// A horizontal scan is displayed alone; only a convincingly wide scan counts
/// as two physical pages. Square illustrations are not alignment anchors.
bool isMergedSpread(PageDimensions page) => page.aspectRatio >= 1.2;

final class SpreadPairingAnalysis {
  const SpreadPairingAnalysis({
    required this.revision,
    required this.rightToLeft,
    required this.shifted,
  });
  static const version = 1;
  final String revision;
  final bool rightToLeft;

  /// Null means insufficient evidence: retain the reading profile's prior.
  final bool? shifted;
  bool matches(ReaderManifest manifest, bool rtl) =>
      revision == manifest.revision && rightToLeft == rtl;
  Map<String, Object?> toJson() => {
    'version': version,
    'revision': revision,
    'rightToLeft': rightToLeft,
    'shifted': shifted,
  };
  static SpreadPairingAnalysis? fromJson(Object? value) {
    if (value is! Map ||
        value['version'] != version ||
        value['revision'] is! String ||
        value['rightToLeft'] is! bool ||
        (value['shifted'] != null && value['shifted'] is! bool)) {
      return null;
    }
    return SpreadPairingAnalysis(
      revision: value['revision'] as String,
      rightToLeft: value['rightToLeft'] as bool,
      shifted: value['shifted'] as bool?,
    );
  }
}

/// Small normalized edge samples; never source-resolution pixel buffers.
final class PageEdgeSample {
  const PageEdgeSample(this.left, this.right);
  final Uint8List left, right;
}

/// Pure, bounded evidence comparison. Uncertain scans deliberately return no
/// conclusion rather than claiming a content/cover detection we cannot make.
final class SpreadPairingAnalyzer {
  static bool? dimensions(List<PageDimensions> pages) {
    var physical = 0, plain = 0, shifted = 0;
    for (final page in pages) {
      if (isMergedSpread(page)) {
        if (physical.isEven) {
          plain++;
        } else {
          shifted++;
        }
        physical += 2;
      } else {
        physical++;
      }
    }
    final total = plain + shifted;
    if (total == 0 || (plain - shifted).abs() / total < .75) return null;
    return shifted > plain;
  }

  /// Edge continuity is supporting evidence, not proof. Reject blank margins
  /// and demand several informative joins and a decisive score difference.
  static bool? visual(
    Map<int, PageEdgeSample> samples, {
    required bool rightToLeft,
  }) {
    final scores = <int, List<double>>{0: [], 1: []};
    for (final index in samples.keys) {
      final next = samples[index + 1];
      if (next == null) continue;
      final first = samples[index]!;
      final a = rightToLeft ? next.right : first.right;
      final b = rightToLeft ? first.left : next.left;
      if (!_informative(a) || !_informative(b)) continue;
      var error = 0.0;
      for (var y = 0; y < a.length; y++) {
        error += (a[y] - b[y]).abs();
      }
      scores[index % 2]!.add(error / a.length / 255);
    }
    if (scores.values.any((values) => values.length < 2)) return null;
    double mean(List<double> values) =>
        values.reduce((a, b) => a + b) / values.length;
    final plain = mean(scores[0]!), shifted = mean(scores[1]!);
    if ((plain - shifted).abs() < .12 ||
        (plain < shifted ? plain : shifted) > .18) {
      return null;
    }
    return shifted < plain;
  }

  static bool _informative(Uint8List edge) {
    if (edge.length != 64) return false;
    var low = 255, high = 0, changes = 0;
    for (var y = 0; y < edge.length; y++) {
      final v = edge[y];
      if (v < low) low = v;
      if (v > high) high = v;
      if (y > 0 && (v - edge[y - 1]).abs() >= 16) changes++;
    }
    return high - low >= 64 && changes >= 8;
  }
}
