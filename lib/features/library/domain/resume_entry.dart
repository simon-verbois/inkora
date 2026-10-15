import 'catalogue.dart';

final class ResumeEntry {
  const ResumeEntry({
    required this.item,
    required this.pageIndex,
    required this.pageCount,
    required this.fraction,
    this.seriesTitle = 'Unknown series',
    this.onDeck = false,
    this.raster = true,
    this.pageKnown = true,
    this.totalProgression,
  });
  final CatalogueItem item;
  final String seriesTitle;
  final int pageIndex, pageCount;
  final double fraction;
  final double? totalProgression;
  final bool raster, pageKnown, onDeck;
  bool get isEbook => item.isEbook || !raster;
  String get readingIdentity => isEbook || item.seriesId == null
      ? item.identity
      : 'series:${item.seriesId}';
  double get progress => onDeck
      ? 0
      : totalProgression ??
            (pageCount < 1
                ? 0
                : ((pageIndex + fraction) / pageCount).clamp(0, 1));
}
