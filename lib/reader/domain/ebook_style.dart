import 'reading_settings.dart';

/// Explicit user choices, independent from catalogue metadata or book titles.
enum EbookStyle {
  publisher(
    'Publisher styles',
    ReadingBackground.sepia,
    'publisher',
    1.5,
    1,
    publisherStyles: true,
  ),
  fantasy('Fantasy', ReadingBackground.sepia, 'gentium', 1.5, 1.1),
  scienceFiction('Science fiction', ReadingBackground.gray, 'lato', 1.5, 1),
  detective(
    'Detective fiction',
    ReadingBackground.slate,
    'pt-serif',
    1.55,
    1.1,
  ),
  classics('Classics', ReadingBackground.paper, 'crimson', 1.5, 1.1),
  study('Study', ReadingBackground.white, 'atkinson', 1.6, 1.1);

  const EbookStyle(
    this.label,
    this.background,
    this.font,
    this.lineHeight,
    this.margins, {
    this.publisherStyles = false,
  });
  final String label, font;
  final bool publisherStyles;
  EbookFont get fontChoice =>
      EbookFont.values.firstWhere((value) => value.id == font);
  final ReadingBackground background;
  final double lineHeight, margins;

  ReadingOverrides apply(ReadingOverrides draft) => ReadingOverrides.fromJson({
    ...draft.toJson(),
    'background': background.name,
    'ebook': {
      ...?draft.ebook,
      'font': font,
      'lineHeight': lineHeight,
      'margins': margins,
      'justify': false,
      'publisherStyles': publisherStyles,
    },
  });

  bool matches(ReadingSettings value) =>
      value.background.current == background &&
      value.ebook.font == font &&
      value.ebook.lineHeight == lineHeight &&
      value.ebook.margins == margins &&
      !value.ebook.justify &&
      value.ebook.publisherStyles == publisherStyles;
}
