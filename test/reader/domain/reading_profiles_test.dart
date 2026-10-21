import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/paged_layout.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

void main() {
  test('manga uses white and legacy dynamic backgrounds adopt white', () {
    expect(
      const ReadingSettings(mode: ReadingMode.manga).background,
      ReadingBackground.white,
    );
    expect(const ReadingSettings().background, ReadingBackground.black);
    final overrides = ReadingOverrides.fromJson({
      'mode': 'manga',
      'background': 'page',
      'spacing': 8,
    });
    expect(
      ReadingSettings.resolve([overrides]).background,
      ReadingBackground.white,
    );
    expect(overrides.toJson()['background'], 'white');
    expect(overrides.spacing, 8);
  });
  test(
    'manga and comics default to two pages only in landscape or on tablets',
    () {
      const manga = ReadingSettings(mode: ReadingMode.manga);
      const comics = ReadingSettings(mode: ReadingMode.comics);
      expect(manga.direction, ReadingDirection.rightToLeft);
      expect(manga.spacing, 0);
      expect(manga.layout, ReadingLayout.automatic);
      expect(comics.direction, ReadingDirection.leftToRight);
      for (final settings in [manga, comics]) {
        // Phone portrait (also a split-screen half) stays single.
        expect(settings.useDoublePages(390, 844), isFalse);
        expect(settings.useDoublePages(500, 700), isFalse);
        // Phone landscape, tablet landscape and tablet portrait pair pages.
        expect(settings.useDoublePages(844, 390), isTrue);
        expect(settings.useDoublePages(1280, 800), isTrue);
        expect(settings.useDoublePages(800, 1280), isTrue);
      }
      // Explicit choices win over the window rule.
      expect(
        const ReadingSettings(
          mode: ReadingMode.manga,
          layout: ReadingLayout.doublePage,
        ).useDoublePages(390, 844),
        isTrue,
      );
      expect(
        const ReadingSettings(
          mode: ReadingMode.manga,
          layout: ReadingLayout.single,
        ).useDoublePages(1280, 800),
        isFalse,
      );
      expect(
        const ReadingSettings(mode: ReadingMode.webtoon).fit,
        ReadingFit.comfort,
      );
    },
  );
  test('different profile resets mode-specific inheritance while shared background survives', () {
    final settings = ReadingSettings.resolve([
      const ReadingOverrides(
        mode: ReadingMode.comics,
        direction: ReadingDirection.leftToRight,
        spreads: false,
        fit: ReadingFit.width,
        spacing: 24,
        background: ReadingBackground.sepia,
      ),
      const ReadingOverrides(mode: ReadingMode.manga),
    ]);
    expect(settings.direction, ReadingDirection.rightToLeft);
    expect(settings.layout, ReadingLayout.automatic);
    expect(settings.spacing, 0);
    expect(settings.fit, ReadingFit.page);
    expect(settings.background, ReadingBackground.sepia);
    final switched = ReadingSettings.resolve([
      const ReadingOverrides(mode: ReadingMode.manga),
      const ReadingOverrides(mode: ReadingMode.comics),
    ]);
    expect(switched.direction, ReadingDirection.leftToRight);
    expect(switched.layout, ReadingLayout.automatic);
  });
  test('same-profile customizations inherit and explicit single/zero override defaults', () {
    final settings = ReadingSettings.resolve([
      const ReadingOverrides(
        mode: ReadingMode.manga,
        direction: ReadingDirection.leftToRight,
        spacing: 24,
      ),
      const ReadingOverrides(mode: ReadingMode.manga),
      const ReadingOverrides(layout: ReadingLayout.single, spacing: 0),
    ]);
    expect(settings.direction, ReadingDirection.leftToRight);
    expect(settings.layout, ReadingLayout.single);
    expect(settings.spacing, 0);
  });
  test(
    'legacy paged/spreads payloads retain direction and explicit presentation',
    () {
      final legacy = ReadingOverrides.fromJson({
        'mode': 'paged',
        'spreads': false,
        'spacing': 8,
        'direction': 'rightToLeft',
      });
      final settings = ReadingSettings.resolve([legacy]);
      expect(settings.mode, ReadingMode.comics);
      expect(settings.direction, ReadingDirection.rightToLeft);
      expect(settings.layout, ReadingLayout.single);
      expect(settings.spacing, 8);
      final roundtrip = ReadingOverrides.fromJson(
        const ReadingOverrides(
          mode: ReadingMode.manga,
          layout: ReadingLayout.doublePage,
        ).toJson(),
      );
      expect(roundtrip.mode, ReadingMode.manga);
      expect(roundtrip.layout, ReadingLayout.doublePage);
    },
  );
  test(
    'wide scans stand alone, odd final pages and every locator map to a group',
    () {
      final layout = PagedLayout([
        PageDimensions(100, 150),
        PageDimensions(100, 200),
        PageDimensions(300, 150),
        PageDimensions(100, 150),
        PageDimensions(100, 150),
        PageDimensions(100, 150),
      ], doublePages: true);
      expect(layout.groups, [
        [0, 1],
        [2],
        [3, 4],
        [5],
      ]);
      expect(layout.groupFor(1), 0);
      expect(layout.groupFor(4), 2);
      expect(layout.adjacent(1, 1), 2);
      expect(layout.adjacent(2, 1), 4);
      expect(layout.adjacent(4, 1), 5);
      expect(layout.adjacent(5, 1), 5);
      expect(layout.adjacent(0, -1), 0);
    },
  );
  test('mixed-ratio spreads share height and use maximum fitting area without a seam gap', () {
    final pages = [PageDimensions(100, 200), PageDimensions(100, 150)];
    final portrait = SpreadGeometry(pages, 390, 844);
    expect(portrait.width, closeTo(390, .001));
    expect(portrait.gap, 0);
    expect(portrait.widths[0] / portrait.height, .5);
    final landscape = SpreadGeometry(pages, 1024, 768);
    expect(landscape.height, 768);
    expect(landscape.width, closeTo(896, .001));
    final wide = SpreadGeometry([PageDimensions(300, 150)], 1024, 768);
    expect(wide.width, 1024);
    final widthFit = SpreadGeometry(pages, 390, 100, fitWidth: true);
    expect(widthFit.width, closeTo(390, .001));
    expect(widthFit.height, greaterThan(100));
  });
}
