import 'dart:math' as math;

import 'reader_manifest.dart';
import 'webtoon_quality.dart';

/// Stable manifest-sized placeholders let scroll position survive image loading.
final class WebtoonLayout {
  /// Portrait stays edge to edge; landscape uses a centered reading column.
  static double readingWidth(
    double width,
    double height, {
    bool fullWidth = false,
  }) => fullWidth || width <= height ? width : math.min(width, height * .85);

  WebtoonLayout(List<PageDimensions> pages, this.width, this.spacing) {
    if (!width.isFinite || width <= 0 || !spacing.isFinite || spacing < 0) {
      throw ArgumentError('Invalid viewport geometry');
    }
    offsets = [0];
    for (final page in pages) {
      final height = width / page.aspectRatio;
      _maximumHeight = math.max(_maximumHeight, height);
      offsets.add(offsets.last + height + spacing);
    }
  }
  final double width;
  final double spacing;
  late final List<double> offsets;
  double _maximumHeight = 0;
  int get pageCount => offsets.length - 1;
  double height(int index) => offsets[index + 1] - offsets[index] - spacing;

  /// Bound the decoded strip overhang at either edge of a prepared window.
  /// Computed from manifest geometry once, never scanned during scrolling.
  double maximumScreenSpan(double viewportHeight) => math.max(
    1.0,
    math.min(
      WebtoonBudget.maxScreensPerStrip.toDouble(),
      _maximumHeight / viewportHeight,
    ),
  );
  ReaderLocator locate(double offset) {
    final position = offset.clamp(0.0, offsets.last);
    var lo = 0;
    var hi = pageCount;
    while (lo + 1 < hi) {
      final mid = (lo + hi) ~/ 2;
      if (offsets[mid] <= position) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return ReaderLocator(
      lo,
      ((position - offsets[lo]) / height(lo)).clamp(0.0, 1.0),
    );
  }

  double offsetFor(ReaderLocator locator) {
    final page = math.min(locator.pageIndex, pageCount - 1);
    return offsets[page] + height(page) * locator.fraction;
  }

  List<int> visible(double offset, double viewportHeight) {
    if (viewportHeight <= 0) return const [];
    final first = locate(offset).pageIndex;
    final last = locate(offset + viewportHeight).pageIndex;
    return [for (var i = first; i <= last; i++) i];
  }

  /// Include strip edges conservatively: a varied-extent sliver can retain
  /// the preceding child at a numerically equal cache boundary. Budget that
  /// whole image too, rather than relying on floating-point equality.
  List<int> prepared(double offset, double viewportHeight, double extent) =>
      visible(offset - extent - 1e-6, viewportHeight + 2 * extent + 2e-6);

  /// Prepare pixels before they enter the viewport, without mounting an entire
  /// chapter of short strips. ListView applies this distance on both sides.
  ///
  /// With [budget], the distance also shrinks (in quarter screens) until the
  /// decode allowances of every strip it would mount fit the memory ceiling,
  /// so tall strips straddling the window edges cannot exceed it.
  double cacheExtent(
    double offset,
    double viewportHeight, {
    int preloadScreens = 4,
    WebtoonBudget? budget,
  }) {
    final extent = _preloadExtent(offset, viewportHeight, preloadScreens);
    if (budget == null) return extent;
    int mounted(double extent) => prepared(offset, viewportHeight, extent).fold(
      0,
      (bytes, index) =>
          bytes +
          decodeBudget(
            index,
            viewportHeight,
            perScreenBytes: budget.perScreenBytes,
          ),
    );
    var fitted = extent;
    while (fitted > 0 && mounted(fitted) > budget.memoryBytes) {
      fitted = math.max(0, fitted - viewportHeight / 4);
    }
    return fitted;
  }

  double _preloadExtent(
    double offset,
    double viewportHeight,
    int preloadScreens,
  ) {
    final pages = visible(offset, viewportHeight);
    if (pages.isEmpty) return 0;
    var extent = viewportHeight * preloadScreens;
    if (pages.first > 4) {
      extent = math.min(extent, offset - offsets[pages.first - 4]);
    }
    if (pages.last + 5 < pageCount) {
      extent = math.min(
        extent,
        offsets[pages.last + 5] - offset - viewportHeight,
      );
    }
    return math.max(0, extent);
  }

  /// Geometry, rather than the changing visible count, determines codec size.
  /// Each strip gets [perScreenBytes] per viewport of displayed height, so the
  /// prepared window's decoded bytes follow its height; short strips share a
  /// screen's allocation and tall strips keep sharpness up to
  /// [WebtoonBudget.maxScreensPerStrip] screens.
  int decodeBudget(
    int index,
    double viewportHeight, {
    int perScreenBytes = 4 * 1024 * 1024,
  }) => math.max(
    4,
    (perScreenBytes *
            math.min(
              WebtoonBudget.maxScreensPerStrip.toDouble(),
              height(index) / viewportHeight,
            ))
        .floor(),
  );
}
