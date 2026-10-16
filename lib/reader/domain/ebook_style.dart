import 'reading_settings.dart';

/// Explicit user choices, independent from catalogue metadata or book titles.
enum EbookStyle {
  fantasy('Fantasy', ReadingBackground.sepia, 'baskerville', 1.65, 1.3),
  scienceFiction(
    'Science fiction',
    ReadingBackground.mist,
    'sans-serif',
    1.55,
    1.1,
  ),
  detective('Detective fiction', ReadingBackground.slate, 'serif', 1.6, 1.2),
  classics('Classics', ReadingBackground.ivory, 'serif', 1.5, 1),
  study('Study', ReadingBackground.sage, 'sans-serif', 1.7, 1.2);

  const EbookStyle(
    this.label,
    this.background,
    this.font,
    this.lineHeight,
    this.margins,
  );
  final String label, font;
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
      'publisherStyles': false,
    },
  });

  bool matches(ReadingSettings value) =>
      value.background == background &&
      value.ebook.font == font &&
      value.ebook.lineHeight == lineHeight &&
      value.ebook.margins == margins &&
      !value.ebook.justify &&
      !value.ebook.publisherStyles;
}
