import '../../../reader/domain/gesture_zones.dart';
import '../../../core/images/image_enhancement.dart';

enum AppAppearance {
  system,
  light,
  dark,
  amoled,
  sepia,
  ocean,
  forest,
  pearl,
  rose,
  midnight,
  plum,
  mint,
  lavender;

  bool get isLight => switch (this) {
    light || sepia || pearl || rose || mint || lavender => true,
    _ => false,
  };
  bool get isDark => this != system && !isLight;
}

final class UiPreferences {
  static const minTextScale = .85;
  static const maxTextScale = 1.3;
  const UiPreferences({
    this.appearance = AppAppearance.system,
    this.systemLightTheme = AppAppearance.light,
    this.systemDarkTheme = AppAppearance.dark,
    this.homePortraitColumns = 3,
    this.homeLandscapeColumns = 6,
    this.textScale = 1,
    this.reduceMotion = false,
    this.hideTags = true,
    this.floatingNavigation = true,
    this.locale,
    this.setupCompleted = false,
    this.setupStep = 0,
    this.gestures = const GestureZones(),
    this.imageEnhancement = ImageEnhancement.balanced,
  });

  final AppAppearance appearance;
  final AppAppearance systemLightTheme, systemDarkTheme;
  AppAppearance get lightTheme =>
      systemLightTheme.isLight ? systemLightTheme : AppAppearance.light;
  AppAppearance get darkTheme =>
      systemDarkTheme.isDark ? systemDarkTheme : AppAppearance.dark;
  final int homePortraitColumns, homeLandscapeColumns;

  int homeColumnsFor(double width, double height) =>
      width > height ? homeLandscapeColumns : homePortraitColumns;
  final double textScale;
  final bool reduceMotion, setupCompleted;
  final bool hideTags;
  final bool floatingNavigation;
  final String? locale;
  final int setupStep;
  final GestureZones gestures;
  final ImageEnhancement imageEnhancement;

  UiPreferences copyWith({
    AppAppearance? appearance,
    AppAppearance? systemLightTheme,
    AppAppearance? systemDarkTheme,
    int? homePortraitColumns,
    int? homeLandscapeColumns,
    double? textScale,
    bool? reduceMotion,
    bool? hideTags,
    bool? floatingNavigation,
    String? locale,
    bool systemLocale = false,
    bool? setupCompleted,
    int? setupStep,
    GestureZones? gestures,
    ImageEnhancement? imageEnhancement,
  }) => UiPreferences(
    appearance: appearance ?? this.appearance,
    systemLightTheme: systemLightTheme ?? this.systemLightTheme,
    systemDarkTheme: systemDarkTheme ?? this.systemDarkTheme,
    homePortraitColumns: homePortraitColumns ?? this.homePortraitColumns,
    homeLandscapeColumns: homeLandscapeColumns ?? this.homeLandscapeColumns,
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    hideTags: hideTags ?? this.hideTags,
    floatingNavigation: floatingNavigation ?? this.floatingNavigation,
    locale: systemLocale ? null : locale ?? this.locale,
    setupCompleted: setupCompleted ?? this.setupCompleted,
    setupStep: setupStep ?? this.setupStep,
    gestures: gestures ?? this.gestures,
    imageEnhancement: imageEnhancement ?? this.imageEnhancement,
  );

  Map<String, Object?> toJson() => {
    'appearance': appearance.name,
    'systemLightTheme': lightTheme.name,
    'systemDarkTheme': darkTheme.name,
    'homePortraitColumns': homePortraitColumns,
    'homeLandscapeColumns': homeLandscapeColumns,
    'textScale': textScale,
    'reduceMotion': reduceMotion,
    'hideTags': hideTags,
    'floatingNavigation': floatingNavigation,
    'locale': locale,
    'setupCompleted': setupCompleted,
    'setupStep': setupStep,
    'setupVersion': 3,
    'gestures': gestures.toJson(),
    'imageEnhancement': imageEnhancement.name,
  };

  factory UiPreferences.fromJson(Map<String, dynamic> json) {
    final scale = json['textScale'];
    final legacyCompact = json['density'] == 'compact';
    int columns(String key, int min, int max, int fallback) {
      final value =
          json[key] ??
          json[key == 'homePortraitColumns'
              ? 'homePhoneColumns'
              : 'homeTabletColumns'];
      return value is int && value >= min && value <= max ? value : fallback;
    }

    final savedStep = json['setupStep'] is int
        ? (json['setupStep'] as int).clamp(0, 8)
        : 0;
    // Preserve the current section when inserting Quality after library defaults.
    final previous = json['setupVersion'] == 2
        ? savedStep.clamp(0, 7)
        : const [0, 2, 3, 3, 4, 5, 6, 6, 7][savedStep];
    final step = json['setupVersion'] == 3
        ? savedStep
        : previous >= 5
        ? previous + 1
        : previous;
    return UiPreferences(
      appearance:
          AppAppearance.values
              .where((value) => value.name == json['appearance'])
              .firstOrNull ??
          AppAppearance.system,
      systemLightTheme:
          AppAppearance.values
              .where(
                (value) =>
                    value.isLight && value.name == json['systemLightTheme'],
              )
              .firstOrNull ??
          AppAppearance.light,
      systemDarkTheme:
          AppAppearance.values
              .where(
                (value) =>
                    value.isDark && value.name == json['systemDarkTheme'],
              )
              .firstOrNull ??
          AppAppearance.dark,
      homePortraitColumns: columns(
        'homePortraitColumns',
        2,
        4,
        legacyCompact ? 4 : 3,
      ),
      homeLandscapeColumns: columns(
        'homeLandscapeColumns',
        5,
        7,
        legacyCompact ? 7 : 6,
      ),
      textScale:
          scale is num &&
              scale.isFinite &&
              scale >= minTextScale &&
              scale <= maxTextScale
          ? scale.toDouble()
          : 1,
      reduceMotion: json['reduceMotion'] == true,
      hideTags: json['hideTags'] != false,
      floatingNavigation: json['floatingNavigation'] != false,
      imageEnhancement: ImageEnhancement.parse(json['imageEnhancement']),
      locale: json['locale'] is String ? json['locale'] as String : null,
      setupCompleted: json['setupCompleted'] == true,
      setupStep: step,
      gestures: json['gestures'] is Map<String, dynamic>
          ? GestureZones.fromJson(json['gestures'] as Map<String, dynamic>)
          : const GestureZones(),
    );
  }
}
