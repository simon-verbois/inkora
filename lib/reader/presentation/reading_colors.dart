import 'package:flutter/material.dart';

import '../domain/reading_settings.dart';

const ebookPaperTextureAsset = 'assets/reader/paper.png';

extension ReadingPaperColors on ReadingBackground {
  Color get paperColor => Color(switch (current) {
    ReadingBackground.black => 0xff000000,
    ReadingBackground.white => 0xfffaf8f4,
    ReadingBackground.sepia => 0xfff4ecd8,
    ReadingBackground.paper => 0xfff4f0e7,
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
