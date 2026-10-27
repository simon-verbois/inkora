import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reading_colors.dart';

void main() {
  test('automatic ink maximizes contrast across the RGB cube', () {
    for (var r = 0; r <= 255; r += 17) {
      for (var g = 0; g <= 255; g += 17) {
        for (var b = 0; b <= 255; b += 17) {
          final color = Color.fromARGB(255, r, g, b);
          final luminance = color.computeLuminance();
          final ink = automaticEbookInk(color);
          final contrast = ink == Colors.black
              ? (luminance + .05) / .05
              : 1.05 / (luminance + .05);
          expect(contrast, greaterThanOrEqualTo(4.5));
          expect(
            contrast,
            greaterThanOrEqualTo(
              ink == Colors.black
                  ? 1.05 / (luminance + .05)
                  : (luminance + .05) / .05,
            ),
          );
        }
      }
    }
  });

  test('custom RGB values validate, roundtrip and inherit independently', () {
    for (final key in ['backgroundColor', 'textColor']) {
      for (final value in [-1, 0x1000000, 1.5, 'ffffff']) {
        expect(
          () => EbookSettings.fromJson({key: value}),
          throwsFormatException,
        );
      }
    }
    final global = ReadingOverrides.fromJson({
      'mode': 'ebook',
      'ebook': {
        'customColors': true,
        'backgroundColor': 0x123456,
        'textColor': 0xabcdef,
        'paperTexture': true,
      },
    });
    for (final scope in SettingsScope.values) {
      final scoped = ReadingOverrides.fromJson({
        'ebook': {'textColor': null},
      });
      final settings = ReadingSettings.resolveScopes({
        SettingsScope.global: global,
        if (scope != SettingsScope.global) scope: scoped,
      });
      expect(settings.ebook.backgroundColor, 0x123456);
      expect(settings.ebookPaperColor, const Color(0xff123456));
      expect(
        settings.ebookInkColor,
        scope == SettingsScope.global ? const Color(0xffabcdef) : Colors.white,
      );
      expect(settings.paperTexture, true);
      expect(EbookSettings.fromJson(settings.ebook.toJson()), settings.ebook);
    }
    final restored = ReadingSettings.resolve([
      ReadingOverrides.fromJson(global.toJson()),
    ]);
    expect(restored.ebookInkColor, const Color(0xffabcdef));
    for (final style in EbookStyle.values) {
      expect(style.matches(restored), false);
      final preset = ReadingSettings.resolve([style.apply(global)]);
      expect(preset.ebook.customColors, false);
      expect(preset.ebookPaperColor, style.background.paperColor);
      expect(style.matches(preset), true);
    }
    expect(
      const EbookSettings(customColors: true),
      isNot(const EbookSettings()),
    );
    expect(
      const ReadingSettings(mode: ReadingMode.ebook).ebookPaperColor,
      ReadingBackground.sepia.paperColor,
    );
  });
}
