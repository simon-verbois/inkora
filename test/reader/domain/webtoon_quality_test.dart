import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/reading_settings.dart';
import 'package:inkora/reader/domain/webtoon_layout.dart';

void main() {
  test(
    'long tablet strips retain decode lookahead within the live ceiling',
    () {
      for (final (width, height) in [(1600.0, 2560.0), (1360.0, 1600.0)]) {
        const ratio = 2.125;
        final viewport = height / ratio;
        final layout = WebtoonLayout(
          [
            for (var i = 0; i < 12; i++)
              PageDimensions(720, i.isEven ? 7000 : 4300),
          ],
          width / ratio,
          0,
        );
        final budget = WebtoonBudget.resolve(
          WebtoonQualityProfile.balanced,
          physicalWidth: width,
          physicalHeight: height,
          maximumStripScreens: layout.maximumScreenSpan(viewport),
        );
        for (var offset = 0.0; offset < layout.offsets.last; offset += 300) {
          final extent = layout.cacheExtent(
            offset,
            viewport,
            preloadScreens: budget.preloadScreens,
            budget: budget,
          );
          expect(extent, greaterThanOrEqualTo(viewport));
          final bytes = layout
              .visible(offset - extent, viewport + 2 * extent)
              .fold<int>(
                0,
                (sum, i) =>
                    sum +
                    layout.decodeBudget(
                      i,
                      viewport,
                      perScreenBytes: budget.perScreenBytes,
                    ),
              );
          expect(bytes, lessThanOrEqualTo(budget.memoryBytes));
        }
      }
    },
  );

  // 1080x2400 phone (physical pixels).
  WebtoonBudget onPhone(WebtoonQualityProfile profile) =>
      WebtoonBudget.resolve(profile, physicalWidth: 1080, physicalHeight: 2400);

  test(
    'presets keep their sharpness and preload within their memory ceiling',
    () {
      for (final quality in [
        WebtoonQuality.saver,
        WebtoonQuality.balanced,
        WebtoonQuality.sharp,
      ]) {
        final profile = WebtoonQualityProfile.preset(quality);
        final budget = onPhone(profile);
        expect(budget.sharpness, profile.sharpness, reason: quality.name);
        expect(
          budget.preloadScreens,
          profile.preloadScreens,
          reason: quality.name,
        );
        expect(
          budget.perScreenBytes *
              WebtoonBudget.residentScreens(budget.preloadScreens),
          lessThanOrEqualTo(budget.memoryBytes),
          reason: quality.name,
        );
      }
      expect(
        onPhone(WebtoonQualityProfile.sharp).perScreenBytes,
        greaterThan(onPhone(WebtoonQualityProfile.saver).perScreenBytes),
      );
    },
  );

  test('the memory ceiling shortens preparation first, then sharpness', () {
    const greedy = WebtoonQualityProfile(
      sharpness: 1,
      preloadScreens: 4,
      memoryMiB: 64,
    );
    final reduced = onPhone(greedy);
    expect(reduced.preloadScreens, lessThan(4));
    expect(reduced.sharpness, 1);
    const tiny = WebtoonQualityProfile(
      sharpness: 1,
      preloadScreens: 4,
      memoryMiB: 32,
    );
    final squeezed = onPhone(tiny);
    expect(squeezed.preloadScreens, 1);
    expect(squeezed.sharpness, lessThan(1));
    expect(
      squeezed.perScreenBytes * WebtoonBudget.residentScreens(1),
      lessThanOrEqualTo(squeezed.memoryBytes),
    );
  });

  test('prepared webtoon windows stay within the resolved memory', () {
    final budget = onPhone(WebtoonQualityProfile.balanced);
    // Mixed short and tall strips, 360 logical px wide at 3x.
    final layout = WebtoonLayout(
      [
        for (var i = 0; i < 300; i++)
          i.isEven ? PageDimensions(800, 600) : PageDimensions(800, 6000),
      ],
      360,
      0,
    );
    const viewport = 800.0;
    for (final offset in [0.0, 12000.0, 90000.0]) {
      final extent = layout.cacheExtent(
        offset,
        viewport,
        preloadScreens: budget.preloadScreens,
        budget: budget,
      );
      final mounted = layout.visible(offset - extent, viewport + 2 * extent);
      final bytes = mounted.fold<int>(
        0,
        (sum, i) =>
            sum +
            layout.decodeBudget(
              i,
              viewport,
              perScreenBytes: budget.perScreenBytes,
            ),
      );
      expect(bytes, lessThanOrEqualTo(budget.memoryBytes), reason: '$offset');
    }
  });

  test('quality settings persist, validate and inherit across scopes', () {
    const custom = ReadingOverrides(
      webtoonQuality: WebtoonQuality.custom,
      webtoonSharpness: .9,
      webtoonPreload: 3,
      webtoonMemoryMiB: 96,
    );
    final restored = ReadingOverrides.fromJson(custom.toJson());
    expect(restored.webtoonQuality, WebtoonQuality.custom);
    expect(restored.webtoonSharpness, .9);
    expect(restored.webtoonPreload, 3);
    expect(restored.webtoonMemoryMiB, 96);
    expect(
      () => ReadingOverrides.fromJson({'webtoonSharpness': 2}),
      throwsFormatException,
    );
    expect(
      () => ReadingOverrides.fromJson({'webtoonMemoryMiB': 4096}),
      throwsFormatException,
    );
    // Older payloads without an explicit choice resolve to high quality.
    expect(
      ReadingSettings.resolve([
        ReadingOverrides.fromJson({'mode': 'webtoon'}),
      ]).webtoonProfile,
      WebtoonQualityProfile.sharp,
    );
    // Global custom values survive a series switching profile and preset.
    final settings = ReadingSettings.resolveScopes({
      SettingsScope.global: custom,
      SettingsScope.series: const ReadingOverrides(mode: ReadingMode.webtoon),
    });
    expect(settings.webtoonProfile.sharpness, .9);
    expect(settings.webtoonProfile.memoryMiB, 96);
    final book = ReadingSettings.resolveScopes({
      SettingsScope.global: custom,
      SettingsScope.book: const ReadingOverrides(
        webtoonQuality: WebtoonQuality.saver,
      ),
    });
    expect(book.webtoonProfile, WebtoonQualityProfile.saver);
    expect(book.customWebtoon.sharpness, .9);
  });
}
