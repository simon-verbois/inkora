/// Persisted ebook typography; no dependency on a rendering toolkit.
final class EbookSettings {
  const EbookSettings({
    this.font = 'publisher',
    this.fontSize = 1.1,
    this.lineHeight = 1.5,
    this.margins = 1.0,
    this.pageInsets,
    this.scroll = false,
    this.columns = 'auto',
    this.publisherStyles = false,
    this.justify = false,
    this.columnSeparator = false,
  });
  final EbookPageInsets? pageInsets;
  final String font, columns;
  final double fontSize, lineHeight, margins;
  final bool scroll, publisherStyles, justify, columnSeparator;
  Map<String, dynamic> toJson() => {
    'font': font,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'margins': margins,
    if (pageInsets != null) 'pageInsets': pageInsets!.toJson(),
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
      pageInsets: json['pageInsets'] == null
          ? null
          : EbookPageInsets.fromJson(
              json['pageInsets'] as Map<String, dynamic>,
            ),
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
      pageInsets == other.pageInsets &&
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
    pageInsets,
    scroll,
    publisherStyles,
    justify,
    columnSeparator,
  );
}

/// Extra publication space in logical pixels, inside the device safe area.
/// Absent values retain the legacy horizontal Readium margin and vertical scale.
final class EbookPageInsets {
  const EbookPageInsets({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final double left, top, right, bottom;
  static const maximum = 160.0;

  factory EbookPageInsets.preset({
    required bool tablet,
    required double scale,
  }) => EbookPageInsets(
    left: (tablet ? 32 : 16) * scale,
    right: (tablet ? 32 : 16) * scale,
    top: (tablet ? 32 : 24) * scale,
    bottom: (tablet ? 32 : 24) * scale,
  );

  Map<String, double> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
  factory EbookPageInsets.fromJson(Map<String, dynamic> json) {
    double edge(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0 || value > maximum) {
        throw const FormatException('Invalid ebook page inset');
      }
      return value.toDouble();
    }

    return EbookPageInsets(
      left: edge('left'),
      top: edge('top'),
      right: edge('right'),
      bottom: edge('bottom'),
    );
  }
  @override
  bool operator ==(Object other) =>
      other is EbookPageInsets &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;
  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}
