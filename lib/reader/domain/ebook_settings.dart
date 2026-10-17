/// Persisted ebook typography; no dependency on a rendering toolkit.
final class EbookSettings {
  const EbookSettings({
    this.font = 'publisher',
    this.fontSize = 1.1,
    this.lineHeight = 1.5,
    this.margins = 1.0,
    this.scroll = false,
    this.columns = 'auto',
    this.publisherStyles = false,
    this.justify = false,
    this.columnSeparator = false,
  });
  final String font, columns;
  final double fontSize, lineHeight, margins;
  final bool scroll, publisherStyles, justify, columnSeparator;
  Map<String, dynamic> toJson() => {
    'font': font,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'margins': margins,
    'scroll': scroll,
    'columns': columns,
    'publisherStyles': publisherStyles,
    'justify': justify,
    'columnSeparator': columnSeparator,
  };
  factory EbookSettings.fromJson(Map<String, dynamic> json) {
    double value(String key, double fallback, double min, double max) {
      final raw = json[key];
      if (raw == null) return fallback;
      if (raw is! num || !raw.isFinite || raw < min || raw > max) {
        throw const FormatException('Invalid ebook typography');
      }
      return raw.toDouble();
    }

    final font = json['font'] as String? ?? 'publisher';
    final columns = json['columns'] as String? ?? 'auto';
    if (!['publisher', 'serif', 'sans-serif', 'baskerville'].contains(font) ||
        !['auto', 'one', 'two'].contains(columns)) {
      throw const FormatException('Invalid ebook layout');
    }
    return EbookSettings(
      font: font,
      columns: columns,
      fontSize: value('fontSize', 1.1, .7, 2.5),
      lineHeight: value('lineHeight', 1.5, 1, 2.5),
      margins: value('margins', 1, .2, 2),
      scroll: json['scroll'] as bool? ?? false,
      publisherStyles: json['publisherStyles'] as bool? ?? false,
      justify: json['justify'] as bool? ?? false,
      columnSeparator: json['columnSeparator'] as bool? ?? false,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is EbookSettings &&
      font == other.font &&
      columns == other.columns &&
      fontSize == other.fontSize &&
      lineHeight == other.lineHeight &&
      margins == other.margins &&
      scroll == other.scroll &&
      publisherStyles == other.publisherStyles &&
      justify == other.justify &&
      columnSeparator == other.columnSeparator;
  @override
  int get hashCode => Object.hash(
    font,
    columns,
    fontSize,
    lineHeight,
    margins,
    scroll,
    publisherStyles,
    justify,
    columnSeparator,
  );
}
