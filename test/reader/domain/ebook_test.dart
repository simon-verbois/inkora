import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/ebook_locator.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

void main() {
  test(
    'publisher typography is the default without replacing explicit choices',
    () {
      expect(const EbookSettings().font, 'publisher');
      expect(const EbookSettings().publisherStyles, true);
      expect(EbookSettings.fromJson({}).publisherStyles, true);
      expect(
        EbookSettings.fromJson({'publisherStyles': false, 'font': 'gentium'})
            .publisherStyles,
        false,
      );
      expect(
        EbookSettings.fromJson({'publisherStyles': false, 'font': 'gentium'})
            .font,
        'gentium',
      );
    },
  );

  test(
    'all font identities survive scoped settings and text zoom stays 100%',
    () {
      for (final font in EbookFont.values) {
        final settings = ReadingSettings.resolve([
          ReadingOverrides.fromJson({
            'mode': 'ebook',
            'ebook': {'fontSize': 2.5, 'lineHeight': 1.8, 'scroll': true},
          }),
          ReadingOverrides.fromJson({
            'ebook': {'font': font.id},
          }),
        ]);
        expect(settings.ebook.fontChoice, font);
        expect(settings.ebook.fontSize, 1.0);
        expect(settings.ebook.lineHeight, 1.8);
        expect(settings.ebook.scroll, isTrue);
        final payload = settings.ebook.toJson();
        expect(payload['fontSize'], 1.0);
        expect(EbookSettings.fromJson(payload), settings.ebook);
      }
      expect(const EbookSettings().fontSize, 1.0);
      expect(EbookSettings.fromJson({'fontSize': .7}).fontSize, 1.0);
      for (final invalid in [double.nan, double.infinity, .6, 3, 'large']) {
        expect(
          () => EbookSettings.fromJson({'fontSize': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => EbookSettings.fromJson({'font': 'missing-family'}),
        throwsFormatException,
      );
    },
  );

  test(
    'ebook presentation preferences preserve explicit scoped false values',
    () {
      final defaults = ReadingSettings.resolve(const []);
      expect(defaults.pageAnimation, isTrue);
      expect(defaults.ebook.columnSeparator, isFalse);
      expect(defaults.ebook.tapToTurnPages, isFalse);
      final parent = ReadingOverrides.fromJson({
        'mode': 'ebook',
        'pageAnimation': false,
        'ebook': {
          'columnSeparator': true,
          'fontSize': 1.4,
          'tapToTurnPages': true,
        },
      });
      final inherited = ReadingSettings.resolve([parent]);
      expect(inherited.pageAnimation, isFalse);
      expect(inherited.ebook.columnSeparator, isTrue);
      expect(inherited.ebook.tapToTurnPages, isTrue);
      final child = ReadingOverrides.fromJson({
        'pageAnimation': true,
        'ebook': {'columnSeparator': false, 'tapToTurnPages': false},
      });
      final resolved = ReadingSettings.resolve([
        ReadingOverrides.fromJson(parent.toJson()),
        ReadingOverrides.fromJson(child.toJson()),
      ]);
      expect(resolved.pageAnimation, isTrue);
      expect(resolved.ebook.columnSeparator, isFalse);
      expect(resolved.ebook.tapToTurnPages, isFalse);
      expect(resolved.ebook.fontSize, 1.0);
      expect(resolved, isNot(inherited));
      expect(
        ReadingSettings.resolve([ReadingOverrides.fromJson({})]),
        defaults,
      );
    },
  );
  final positions = [
    for (var i = 0; i < 4; i++)
      {
        'href': i < 3 ? 'chapter.xhtml' : 'end.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {
          'position': i + 1,
          'progression': i < 3 ? i / 2 : 0.0,
          'totalProgression': i / 3,
        },
      },
  ];
  test(
    'native positions map to Komga resource positions without screen pages',
    () {
      final native = EbookLocator({
        'href': 'chapter.xhtml#text',
        'type': 'application/xhtml+xml',
        'locations': {'position': 999, 'progression': .73},
        'text': {'highlight': 'Reading anchor'},
      });
      final mapped = native.forKomga(positions);
      expect(mapped.positionIn(positions), 1);
      expect(mapped.locations['position'], 2);
      expect(mapped.progression, .73);
      expect(mapped.value['text'], {'highlight': 'Reading anchor'});
      expect(
        () => EbookLocator({
          'href': 'missing',
          'type': 'text/html',
          'locations': {'progression': .2},
        }).positionIn(positions),
        throwsFormatException,
      );
    },
  );
  test(
    'exact progression survives beyond the final canonical segment start',
    () {
      final native = EbookLocator({
        'href': 'end.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {'progression': .83},
        'text': {'highlight': 'Last chapter anchor'},
      });
      final (index, mapped) = EbookPositionMap(positions).map(native);
      expect(index, 3);
      expect(mapped.progression, .83);
      expect(mapped.locations['position'], 4);
      expect(mapped.value['text'], native.value['text']);
      expect(native.forKomga(positions).progression, .83);
    },
  );
  test(
    'ebook profile resets raster geometry and inherits scoped typography',
    () {
      final settings = ReadingSettings.resolve([
        const ReadingOverrides(
          mode: ReadingMode.manga,
          layout: ReadingLayout.doublePage,
          ebook: {'fontSize': 1.3},
        ),
        const ReadingOverrides(
          mode: ReadingMode.ebook,
          ebook: {'lineHeight': 1.8},
        ),
      ]);
      expect(settings.mode, ReadingMode.ebook);
      expect(settings.direction, ReadingDirection.leftToRight);
      expect(settings.layout, ReadingLayout.single);
      expect(settings.background, ReadingBackground.sepia);
      expect(settings.ebook.fontSize, 1.0);
      expect(settings.ebook.lineHeight, 1.8);
      expect(
        () => ReadingOverrides.fromJson({
          'ebook': {'fontSize': double.infinity},
        }),
        throwsFormatException,
      );
      expect(
        () => EbookLocator({
          'href': 'a',
          'type': 'text/html',
          'locations': {'progression': -1},
        }),
        throwsFormatException,
      );
    },
  );
}
