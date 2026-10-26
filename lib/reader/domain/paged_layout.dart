import 'dart:math' as math;

import 'reader_manifest.dart';
import 'spread_pairing.dart';

/// Logical groups retain server order; presentation alone reverses for manga.
final class PagedLayout {
  /// [offset] selects physical-page parity. A merged scan occupies two slots;
  /// it does not restart a leading-page offset after every horizontal image.
  PagedLayout(this.dimensions, {required this.doublePages, this.offset = 0}) {
    final pages = dimensions;
    pageGroups = List.filled(pages.length, 0);
    var physical = 0;
    for (var index = 0; index < pages.length;) {
      final group = [index++];
      if (pages[group.first].aspectRatio >= 1) {
        physical += isMergedSpread(pages[group.first]) ? 2 : 1;
      } else if (doublePages &&
          (physical - offset).isEven &&
          index < pages.length &&
          pages[index].aspectRatio < 1) {
        group.add(index++);
        physical += 2;
      } else {
        physical++;
      }
      for (final page in group) {
        pageGroups[page] = groups.length;
      }
      groups.add(List.unmodifiable(group));
    }
  }
  final groups = <List<int>>[];
  final List<PageDimensions> dimensions;
  final bool doublePages;
  final int offset;
  late final List<int> pageGroups;
  int groupFor(int page) => pageGroups[page];
  List<int> pagesFor(int page) => groups[groupFor(page)];
  int adjacent(int page, int delta) {
    final current = groupFor(page);
    final next = (current + delta).clamp(0, groups.length - 1);
    return next == current ? page : groups[next].last;
  }
}

/// All pages share a fitted height, making the inner seam touch even when their
/// aspect ratios differ. The last odd page or a wide scan uses the full viewport.
final class SpreadGeometry {
  SpreadGeometry(
    List<PageDimensions> pages,
    double availableWidth,
    double availableHeight, {
    double spacing = 0,
    bool fitWidth = false,
  }) {
    gap = math.min(spacing, availableWidth / 2);
    final gaps = gap * (pages.length - 1);
    final ratio = pages.fold(0.0, (sum, page) => sum + page.aspectRatio);
    final fitted = (availableWidth - gaps) / ratio;
    height = fitWidth ? fitted : math.min(availableHeight, fitted);
    widths = [for (final page in pages) height * page.aspectRatio];
    width = widths.fold(0.0, (sum, value) => sum + value) + gaps;
  }
  late final double width, height, gap;
  late final List<double> widths;
}
