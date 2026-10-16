import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reading_colors.dart';

void main() {
  test('manual styles compose with scoped typography, preserve font scaling and layout and serialize', () {
    for (final style in EbookStyle.values) {
      final applied = style.apply(
        const ReadingOverrides(
          mode: ReadingMode.ebook,
          ebook: {'fontSize': 1.8, 'scroll': true, 'columns': 'one'},
        ),
      );
      final restored = ReadingOverrides.fromJson(applied.toJson());
      final settings = ReadingSettings.resolve([restored]);
      expect(style.matches(settings), true);
      expect(settings.ebook.fontSize, 1.8);
      expect(settings.ebook.scroll, true);
      expect(settings.ebook.columns, 'one');
      expect(EbookSettings.fromJson(settings.ebook.toJson()), settings.ebook);
    }
  });
  test('sepia is the unconfigured ebook default and explicit choices stay authoritative', () {
    expect(
      const ReadingSettings(mode: ReadingMode.ebook).background,
      ReadingBackground.sepia,
    );
    expect(
      const ReadingSettings(mode: ReadingMode.manga).background,
      ReadingBackground.white,
    );
    for (final background in ReadingBackground.values) {
      final settings = ReadingSettings.resolve([
        ReadingOverrides(mode: ReadingMode.ebook, background: background),
      ]);
      expect(settings.background, background);
      final a = background.paperColor.computeLuminance(),
          b = background.inkColor.computeLuminance();
      final ratio = (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
