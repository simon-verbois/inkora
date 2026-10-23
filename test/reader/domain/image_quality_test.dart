import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/reading_settings.dart';

void main() {
  test('high defaults adopt legacy payloads and preserve explicit quality', () {
    final settings = ReadingSettings.resolve([
      ReadingOverrides.fromJson({'mode': 'webtoon'}),
    ]);
    expect(settings.webtoonQuality, WebtoonQuality.sharp);
    expect(settings.qualityFor('image/png').sampling, ImageSampling.high);
    expect(
      ReadingSettings.resolve([
        const ReadingOverrides(webtoonQuality: WebtoonQuality.balanced),
      ]).webtoonQuality,
      WebtoonQuality.balanced,
    );
    expect(
      RasterFormat.fromMediaType('IMAGE/JPEG; charset=binary'),
      RasterFormat.jpeg,
    );
    expect(RasterFormat.fromMediaType('image/avif'), RasterFormat.other);
  });
  test('format overrides round trip, inherit separately and ignore profile changes', () {
    final global = ReadingOverrides.fromJson(
      jsonDecode(
        jsonEncode(
          const ReadingOverrides(
            imageQuality: {
              RasterFormat.jpeg: RasterQuality(sampling: ImageSampling.nearest),
              RasterFormat.png: RasterQuality(filter: VisualFilter.grayscale),
            },
          ).toJson(),
        ),
      ) as Map<String, dynamic>,
    );
    final resolved = ReadingSettings.resolveScopes({
      SettingsScope.global: global,
      SettingsScope.library: const ReadingOverrides(
        mode: ReadingMode.manga,
        imageQuality: {
          RasterFormat.png: RasterQuality(filter: VisualFilter.sepia),
        },
      ),
      SettingsScope.book: const ReadingOverrides(mode: ReadingMode.webtoon),
    });
    expect(resolved.qualityFor('image/jpeg').sampling, ImageSampling.high);
    expect(resolved.qualityFor('image/png').filter, VisualFilter.sepia);
    expect(
      resolved.qualityFor('image/webp'),
      const RasterQuality(filter: VisualFilter.sepia),
    );
    expect(
      resolved,
      ReadingSettings.resolveScopes({
        SettingsScope.global: global,
        SettingsScope.library: const ReadingOverrides(
          mode: ReadingMode.manga,
          imageQuality: {
            RasterFormat.png: RasterQuality(filter: VisualFilter.sepia),
          },
        ),
        SettingsScope.book: const ReadingOverrides(mode: ReadingMode.webtoon),
      }),
    );
    expect(
      resolved.hashCode,
      ReadingSettings.resolveScopes({
        SettingsScope.global: global,
        SettingsScope.library: const ReadingOverrides(
          mode: ReadingMode.manga,
          imageQuality: {
            RasterFormat.png: RasterQuality(filter: VisualFilter.sepia),
          },
        ),
        SettingsScope.book: const ReadingOverrides(mode: ReadingMode.webtoon),
      }).hashCode,
    );
  });
}
