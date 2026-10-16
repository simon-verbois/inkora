import 'ebook_settings.dart';
export 'ebook_settings.dart';
import 'webtoon_quality.dart';
import 'image_quality.dart';
export 'image_quality.dart';

export 'webtoon_quality.dart';

enum ReadingMode {
  comics,
  manga,
  webtoon,
  ebook;

  // Compatibility for earlier callers; persisted "paged" maps to comics.
  static const paged = comics;
}

enum ReadingLayout { single, doublePage, automatic }

enum ReadingDirection { leftToRight, rightToLeft, vertical }

enum ReadingFit { page, width, comfort }

enum ReadingBackground { black, white, sepia, ivory, sage, mist, slate }

enum SettingsScope { global, library, series, book }

final class ReadingOverrides {
  const ReadingOverrides({
    this.mode,
    this.direction,
    this.fit,
    this.background,
    this.spacing,
    this.spreads,
    this.layout,
    this.libraryDefaults = false,
    this.webtoonQuality,
    this.webtoonSharpness,
    this.webtoonPreload,
    this.webtoonMemoryMiB,
    this.spreadOffset,
    this.imageQuality,
    this.ebook,
  });
  final ReadingMode? mode;
  final Map<String, dynamic>? ebook;
  final ReadingDirection? direction;
  final ReadingFit? fit;
  final ReadingBackground? background;
  final double? spacing;
  final bool? spreads;
  final ReadingLayout? layout;
  final bool libraryDefaults;

  /// Webtoon image quality: preset, plus the custom slider values. These are
  /// independent of the reading profile and survive mode changes.
  final WebtoonQuality? webtoonQuality;
  final double? webtoonSharpness;
  final int? webtoonPreload;
  final int? webtoonMemoryMiB;

  /// Shift double-page pairing by one page (the first page stands alone).
  final bool? spreadOffset;
  final Map<RasterFormat, RasterQuality>? imageQuality;
  ReadingLayout? get effectiveLayout =>
      layout ??
      (spreads == null
          ? null
          : spreads!
          ? ReadingLayout.automatic
          : ReadingLayout.single);
  Map<String, Object?> toJson() => {
    'mode': mode?.name,
    if (ebook != null) 'ebook': ebook,
    'direction': direction?.name,
    'fit': fit?.name,
    'background': background?.name,
    'spacing': spacing,
    'spreads': spreads,
    'layout': layout?.name,
    'libraryDefaults': libraryDefaults,
    'webtoonQuality': webtoonQuality?.name,
    'webtoonSharpness': webtoonSharpness,
    'webtoonPreload': webtoonPreload,
    'webtoonMemoryMiB': webtoonMemoryMiB,
    'spreadOffset': spreadOffset,
    'imageQuality': imageQuality == null
        ? null
        : {
            for (final entry in imageQuality!.entries)
              entry.key.name: entry.value.toJson(),
          },
  };
  factory ReadingOverrides.fromJson(Map<String, dynamic> json) {
    T? parse<T extends Enum>(List<T> values, String key) => json[key] == null
        ? null
        : values.firstWhere((v) => v.name == json[key]);
    final spacing = (json['spacing'] as num?)?.toDouble();
    if (spacing != null && (!spacing.isFinite || spacing < 0 || spacing > 64)) {
      throw const FormatException('Invalid page spacing');
    }
    final sharpness = (json['webtoonSharpness'] as num?)?.toDouble();
    final preload = (json['webtoonPreload'] as num?)?.toInt();
    final memory = (json['webtoonMemoryMiB'] as num?)?.toInt();
    WebtoonQualityProfile.validate(
      sharpness: sharpness,
      preload: preload,
      memoryMiB: memory,
    );
    final ebook = json['ebook'] as Map<String, dynamic>?;
    if (ebook != null) EbookSettings.fromJson(ebook);
    return ReadingOverrides(
      ebook: ebook,
      mode: json['mode'] == 'paged'
          ? ReadingMode.comics
          : parse(ReadingMode.values, 'mode'),
      direction: parse(ReadingDirection.values, 'direction'),
      fit: parse(ReadingFit.values, 'fit'),
      // Adopt the removed dynamic background without losing other preferences.
      background: json['background'] == 'page'
          ? ReadingBackground.white
          : parse(ReadingBackground.values, 'background'),
      spacing: spacing,
      spreads: json['spreads'] as bool?,
      layout: parse(ReadingLayout.values, 'layout'),
      libraryDefaults: json['libraryDefaults'] as bool? ?? false,
      webtoonQuality: parse(WebtoonQuality.values, 'webtoonQuality'),
      webtoonSharpness: sharpness,
      webtoonPreload: preload,
      webtoonMemoryMiB: memory,
      spreadOffset: json['spreadOffset'] as bool?,
      imageQuality: json['imageQuality'] is Map
          ? Map.unmodifiable({
              for (final format in RasterFormat.values)
                if ((json['imageQuality'] as Map)[format.name]
                    is Map<String, dynamic>)
                  format: RasterQuality.fromJson(
                    (json['imageQuality'] as Map)[format.name]
                        as Map<String, dynamic>,
                  ),
            })
          : null,
    );
  }
}

final class ReadingSettings {
  const ReadingSettings({
    this.mode = ReadingMode.comics,
    ReadingDirection? direction,
    ReadingFit? fit,
    ReadingBackground? background,
    double? spacing,
    ReadingLayout? layout,
    bool? spreads,
    this.webtoonQuality = WebtoonQuality.sharp,
    this.customWebtoon = WebtoonQualityProfile.balanced,
    this.spreadOffset = false,
    this.imageQuality = const {},
    this.ebook = const EbookSettings(),
  }) : background =
           background ??
           (mode == ReadingMode.ebook
               ? ReadingBackground.sepia
               : mode == ReadingMode.manga
               ? ReadingBackground.white
               : ReadingBackground.black),
       direction =
           direction ??
           (mode == ReadingMode.manga
               ? ReadingDirection.rightToLeft
               : ReadingDirection.leftToRight),
       fit =
           fit ??
           (mode == ReadingMode.webtoon ? ReadingFit.comfort : ReadingFit.page),
       spacing = spacing ?? 0,
       layout =
           layout ??
           (spreads != null
               ? (spreads ? ReadingLayout.automatic : ReadingLayout.single)
               : mode == ReadingMode.manga
               ? ReadingLayout.doublePage
               : mode == ReadingMode.comics
               ? ReadingLayout.automatic
               : ReadingLayout.single);
  final ReadingMode mode;
  final EbookSettings ebook;
  final ReadingDirection direction;
  final ReadingFit fit;
  final ReadingBackground background;
  final double spacing;
  final ReadingLayout layout;
  final WebtoonQuality webtoonQuality;
  final bool spreadOffset;
  final Map<RasterFormat, RasterQuality> imageQuality;
  RasterQuality qualityFor(String mediaType) =>
      imageQuality[RasterFormat.fromMediaType(mediaType)] ??
      const RasterQuality();

  /// Slider values used when [webtoonQuality] is custom (kept otherwise so
  /// switching back to custom restores them).
  final WebtoonQualityProfile customWebtoon;
  WebtoonQualityProfile get webtoonProfile =>
      webtoonQuality == WebtoonQuality.custom
      ? customWebtoon
      : WebtoonQualityProfile.preset(webtoonQuality);
  bool get spreads => layout != ReadingLayout.single;
  bool useDoublePages(double width, double height) => switch (layout) {
    ReadingLayout.single => false,
    ReadingLayout.doublePage => true,
    ReadingLayout.automatic => width >= 600 && width > height,
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingSettings &&
      mode == other.mode &&
      ebook == other.ebook &&
      direction == other.direction &&
      fit == other.fit &&
      background == other.background &&
      spacing == other.spacing &&
      layout == other.layout &&
      webtoonQuality == other.webtoonQuality &&
      customWebtoon == other.customWebtoon &&
      spreadOffset == other.spreadOffset &&
      RasterFormat.values.every(
        (format) =>
            (imageQuality[format] ?? const RasterQuality()) ==
            (other.imageQuality[format] ?? const RasterQuality()),
      );
  @override
  int get hashCode => Object.hash(
    mode,
    ebook,
    direction,
    fit,
    background,
    spacing,
    layout,
    webtoonQuality,
    customWebtoon,
    spreadOffset,
    Object.hashAll(
      RasterFormat.values.map(
        (format) => imageQuality[format] ?? const RasterQuality(),
      ),
    ),
  );

  static ReadingSettings resolveScopes(
    Map<SettingsScope, ReadingOverrides> layers,
  ) => resolve([
    for (final scope in SettingsScope.values)
      if (layers[scope] != null &&
          !(scope == SettingsScope.series &&
              layers[SettingsScope.book]?.libraryDefaults == true))
        layers[scope]!,
  ]);

  static ReadingSettings resolve(Iterable<ReadingOverrides> layers) {
    var mode = ReadingMode.comics;
    ReadingDirection? direction;
    ReadingFit? fit;
    ReadingBackground? background;
    double? spacing;
    ReadingLayout? layout;
    WebtoonQuality? quality;
    double? sharpness;
    int? preload;
    int? memory;
    bool? offset;
    final ebook = <String, dynamic>{};
    final images = <RasterFormat, RasterQuality>{};
    for (final layer in layers) {
      final value = layer.spacing;
      if (value != null && (!value.isFinite || value < 0 || value > 64)) {
        throw ArgumentError('Spacing must be between 0 and 64');
      }
      // A different reading profile starts from its own defaults. Background
      // is shared; scoped customizations within the same profile still inherit.
      if (layer.mode != null && layer.mode != mode) {
        mode = layer.mode!;
        direction = null;
        fit = null;
        spacing = null;
        layout = null;
      }
      direction = layer.direction ?? direction;
      fit = layer.fit ?? fit;
      background = layer.background ?? background;
      spacing = layer.spacing ?? spacing;
      layout = layer.effectiveLayout ?? layout;
      quality = layer.webtoonQuality ?? quality;
      sharpness = layer.webtoonSharpness ?? sharpness;
      preload = layer.webtoonPreload ?? preload;
      memory = layer.webtoonMemoryMiB ?? memory;
      offset = layer.spreadOffset ?? offset;
      ebook.addAll(layer.ebook ?? const {});
      images.addAll(layer.imageQuality ?? const {});
    }
    return ReadingSettings(
      mode: mode,
      ebook: EbookSettings.fromJson(ebook),
      direction: direction,
      fit: fit,
      background: background,
      spacing: spacing,
      layout: layout,
      webtoonQuality: quality ?? WebtoonQuality.sharp,
      imageQuality: Map.unmodifiable(images),
      spreadOffset: offset ?? false,
      customWebtoon: WebtoonQualityProfile(
        sharpness: sharpness ?? WebtoonQualityProfile.balanced.sharpness,
        preloadScreens:
            preload ?? WebtoonQualityProfile.balanced.preloadScreens,
        memoryMiB: memory ?? WebtoonQualityProfile.balanced.memoryMiB,
      ),
    );
  }
}
