import 'package:flutter/material.dart';

import '../domain/reading_settings.dart';

extension ReadingPaperColors on ReadingBackground {
  Color get paperColor => Color(switch (this) {
    ReadingBackground.black => 0xff000000,
    ReadingBackground.white => 0xfffaf8f4,
    ReadingBackground.sepia => 0xfff4ecd8,
    ReadingBackground.ivory => 0xfffffaf0,
    ReadingBackground.sage => 0xffe7efdf,
    ReadingBackground.mist => 0xffe8eef2,
    ReadingBackground.slate => 0xff19242c,
  });
  Color get inkColor => Color(switch (this) {
    ReadingBackground.black => 0xffe8e4dc,
    ReadingBackground.slate => 0xffe2e7eb,
    ReadingBackground.sage => 0xff263323,
    ReadingBackground.mist => 0xff21313c,
    _ => 0xff252320,
  });
}
