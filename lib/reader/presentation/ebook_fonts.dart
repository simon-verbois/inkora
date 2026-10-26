import 'package:flutter_readium/flutter_readium.dart';

import '../domain/ebook_settings.dart';

extension EbookFontPresentation on EbookFont {
  String? get previewFamily => switch (this) {
    EbookFont.publisher || EbookFont.serif || EbookFont.sansSerif => null,
    EbookFont.baskerville => 'LibreBaskerville',
    EbookFont.atkinson => 'AtkinsonHyperlegible',
    EbookFont.crimson => 'CrimsonText',
    EbookFont.gentium => 'GentiumBookPlus',
    EbookFont.lato => 'Lato',
    EbookFont.ptSerif => 'PTSerif',
  };

  String? get nativeFamily => switch (this) {
    EbookFont.publisher => null,
    EbookFont.serif || EbookFont.sansSerif => id,
    EbookFont.baskerville => 'InkoraBaskerville',
    _ => previewFamily,
  };

  String get fallback => switch (this) {
    EbookFont.atkinson || EbookFont.lato || EbookFont.sansSerif => 'sans-serif',
    _ => 'serif',
  };
}

/// Declared once, outside builds and locator/page events. Native readers serve
/// these bundled files locally; only selected font faces need to be requested.
final ebookFontDeclarations = List<ReaderFontFamily>.unmodifiable([
  for (final font in EbookFont.values)
    if (font.previewFamily != null)
      ReaderFontFamily(
        name: font.nativeFamily!,
        fallbacks: [font.fallback],
        faces: font == EbookFont.baskerville
            ? const [ReaderFontFace(asset: 'assets/fonts/LibreBaskerville.ttf')]
            : [
                for (final (suffix, weight, style) in const [
                  ('Regular', 400, ReaderFontStyle.normal),
                  ('Italic', 400, ReaderFontStyle.italic),
                  ('Bold', 700, ReaderFontStyle.normal),
                  ('BoldItalic', 700, ReaderFontStyle.italic),
                ])
                  ReaderFontFace(
                    asset: 'assets/fonts/${font.previewFamily}-$suffix.ttf',
                    weight: weight,
                    style: style,
                  ),
              ],
      ),
]);
