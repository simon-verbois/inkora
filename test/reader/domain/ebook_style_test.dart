import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_style.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/presentation/reading_colors.dart';

void main() {
  test(
    'retired background IDs remain serializable and map to the reduced palette',
    () {
      for (final (old, current) in [
        (ReadingBackground.ivory, ReadingBackground.paper),
        (ReadingBackground.sage, ReadingBackground.gray),
        (ReadingBackground.mist, ReadingBackground.gray),
      ]) {
        final saved = ReadingOverrides.fromJson({'background': old.name});
        expect(saved.toJson()['background'], old.name);
        expect(ReadingSettings.resolve([saved]).background.current, current);
      }
      expect(EbookStyle.classics.background, ReadingBackground.paper);
      expect(EbookStyle.scienceFiction.background, ReadingBackground.gray);
      expect(EbookStyle.study.background, ReadingBackground.white);
    },
  );

  test(
    'templates offer publisher restoration and distinct real reading families',
    () {
      expect(EbookStyle.values, hasLength(6));
      expect(
        EbookStyle.values.map((style) => style.font).toSet(),
        hasLength(6),
      );
      expect(
        EbookStyle.publisher.matches(
          const ReadingSettings(mode: ReadingMode.ebook),
        ),
        true,
      );
      expect(EbookStyle.fantasy.font, 'gentium');
      final custom = EbookStyle.fantasy.apply(
        const ReadingOverrides(
          ebook: {
            'publisherStyles': true,
            'pageInsets': {'left': 10, 'right': 10, 'top': 10, 'bottom': 10},
          },
        ),
      );
      expect(custom.ebook!['publisherStyles'], false);
      expect(custom.ebook!['pageInsets'], isNotNull);
      final restored = EbookStyle.publisher.apply(custom);
      expect(restored.ebook!['font'], 'publisher');
      expect(restored.ebook!['publisherStyles'], true);
    },
  );

  test('manual styles compose with scoped typography, normalize legacy text zoom and preserve layout and serialize', () {
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
      expect(settings.ebook.fontSize, 1.0);
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
