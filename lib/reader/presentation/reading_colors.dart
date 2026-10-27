import 'package:flutter/material.dart';

import '../domain/reading_settings.dart';

const ebookPaperTextureAsset = 'assets/reader/paper.png';

extension ReadingPaperColors on ReadingBackground {
  Color get paperColor => Color(switch (current) {
    ReadingBackground.black => 0xff000000,
    ReadingBackground.white => 0xfffaf8f4,
    ReadingBackground.sepia => 0xfff4ecd8,
    ReadingBackground.gray => 0xffd8d8d6,
    ReadingBackground.slate => 0xff242424,
    _ => throw StateError('Retired paper color'),
  });
  Color get inkColor => Color(switch (current) {
    ReadingBackground.black => 0xffe8e4dc,
    ReadingBackground.slate => 0xffe2e7eb,

    _ => 0xff252320,
  });
}

/// Select whichever opaque ink has the greater contrast against the chosen fill.
Color automaticEbookInk(Color background) {
  final luminance = background.computeLuminance();
  return (luminance + .05) / .05 >= 1.05 / (luminance + .05)
      ? Colors.black
      : Colors.white;
}

extension CustomEbookColors on ReadingSettings {
  Color get ebookPaperColor => ebook.customColors
      ? Color(0xff000000 | ebook.backgroundColor)
      : background.paperColor;
  Color get ebookInkColor => ebook.customColors
      ? ebook.textColor == null
            ? automaticEbookInk(ebookPaperColor)
            : Color(0xff000000 | ebook.textColor!)
      : background.inkColor;
}
