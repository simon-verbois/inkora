import 'reading_settings.dart';

/// Appearance choices retain publisher layout, spacing and relative text sizes.
enum EbookStyle {
  publisher('Publisher styles', ReadingBackground.sepia, 'publisher'),
  fantasy('Fantasy', ReadingBackground.sepia, 'gentium'),
  scienceFiction('Science fiction', ReadingBackground.gray, 'lato'),
  detective('Detective fiction', ReadingBackground.slate, 'pt-serif'),
  classics('Classics', ReadingBackground.white, 'crimson', paperTexture: true),
  study('Study', ReadingBackground.white, 'atkinson');

  const EbookStyle(
    this.label,
    this.background,
    this.font, {
    this.paperTexture = false,
  });
  final String label, font;
  final bool paperTexture;
  EbookFont get fontChoice =>
      EbookFont.values.firstWhere((value) => value.id == font);
  final ReadingBackground background;

  ReadingOverrides apply(ReadingOverrides draft) => ReadingOverrides.fromJson({
    ...draft.toJson(),
    'background': background.name,
    'ebook': {
      ...?draft.ebook,
      'font': font,
      // Readium applies font selection independently of publisher layout.
      // Keep the publication's alignment, line/paragraph/word spacing intact.
      'publisherStyles': true,
      'paperTexture': paperTexture,
      'customColors': false,
    },
  });

  bool matches(ReadingSettings value) =>
      !value.ebook.customColors &&
      value.background.current == background &&
      value.paperTexture == paperTexture &&
      value.ebook.font == font &&
      value.ebook.publisherStyles;
}
