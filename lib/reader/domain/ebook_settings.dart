/// Stable persisted identities; font files and renderer declarations live in UI.
enum EbookFont {
  publisher('publisher', 'Publisher font'),
  serif('serif', 'Serif'),
  sansSerif('sans-serif', 'Sans serif'),
  baskerville('baskerville', 'Libre Baskerville'),
  atkinson('atkinson', 'Atkinson Hyperlegible'),
  crimson('crimson', 'Crimson Text'),
  gentium('gentium', 'Gentium Book Plus'),
  lato('lato', 'Lato'),
  ptSerif('pt-serif', 'PT Serif');

  const EbookFont(this.id, this.label);
  final String id, label;
}

/// Persisted ebook typography; no dependency on a rendering toolkit.
final class EbookSettings {
  const EbookSettings({
    this.font = 'publisher',
    this.lineHeight = 1.5,
    this.margins = 1.0,
    this.pageInsets,
    this.scroll = false,
    this.columns = 'auto',
    this.publisherStyles = true,
    this.justify = false,
    this.columnSeparator = false,
    this.tapToTurnPages = false,
  });
  final EbookPageInsets? pageInsets;
  final String font, columns;

  /// Text zoom is fixed; legacy saved factors are validated but not applied.
  final double fontSize = 1.0;
  final double lineHeight, margins;
  EbookFont get fontChoice => EbookFont.values.firstWhere((v) => v.id == font);
  final bool scroll, publisherStyles, justify, columnSeparator, tapToTurnPages;
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
    'tapToTurnPages': tapToTurnPages,
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
    if (!EbookFont.values.any((choice) => choice.id == font) ||
        !['auto', 'one', 'two'].contains(columns)) {
      throw const FormatException('Invalid ebook layout');
    }
    // Retain validation for old settings/imports without retaining text zoom.
    value('fontSize', 1, .7, 2.5);
    return EbookSettings(
      font: font,
      columns: columns,
      lineHeight: value('lineHeight', 1.5, 1, 2.5),
      margins: value('margins', 1, .2, 2),
      pageInsets: json['pageInsets'] == null
          ? null
          : EbookPageInsets.fromJson(
              json['pageInsets'] as Map<String, dynamic>,
            ),
      scroll: json['scroll'] as bool? ?? false,
      publisherStyles: json['publisherStyles'] as bool? ?? true,
      justify: json['justify'] as bool? ?? false,
      columnSeparator: json['columnSeparator'] as bool? ?? false,
      tapToTurnPages: json['tapToTurnPages'] as bool? ?? false,
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
      columnSeparator == other.columnSeparator &&
      tapToTurnPages == other.tapToTurnPages;
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
    tapToTurnPages,
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
