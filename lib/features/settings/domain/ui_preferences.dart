import '../../../reader/domain/gesture_zones.dart';

enum AppAppearance { system, light, dark, amoled, sepia, ocean, forest }

enum CatalogueDensity { comfortable, compact }

final class UiPreferences {
  static const textScales = [1.0, 1.15, 1.3];
  const UiPreferences({
    this.appearance = AppAppearance.system,
    this.density = CatalogueDensity.comfortable,
    this.textScale = 1,
    this.reduceMotion = false,
    this.locale,
    this.setupCompleted = false,
    this.setupStep = 0,
    this.gestures = const GestureZones(),
  });

  final AppAppearance appearance;
  final CatalogueDensity density;
  final double textScale;
  final bool reduceMotion, setupCompleted;
  final String? locale;
  final int setupStep;
  final GestureZones gestures;

  UiPreferences copyWith({
    AppAppearance? appearance,
    CatalogueDensity? density,
    double? textScale,
    bool? reduceMotion,
    String? locale,
    bool systemLocale = false,
    bool? setupCompleted,
    int? setupStep,
    GestureZones? gestures,
  }) => UiPreferences(
    appearance: appearance ?? this.appearance,
    density: density ?? this.density,
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    locale: systemLocale ? null : locale ?? this.locale,
    setupCompleted: setupCompleted ?? this.setupCompleted,
    setupStep: setupStep ?? this.setupStep,
    gestures: gestures ?? this.gestures,
  );

  Map<String, Object?> toJson() => {
    'appearance': appearance.name,
    'density': density.name,
    'textScale': textScale,
    'reduceMotion': reduceMotion,
    'locale': locale,
    'setupCompleted': setupCompleted,
    'setupStep': setupStep,
    'setupVersion': 2,
    'gestures': gestures.toJson(),
  };

  factory UiPreferences.fromJson(Map<String, dynamic> json) {
    final scale = json['textScale'];
    final savedStep = json['setupStep'] is int
        ? (json['setupStep'] as int).clamp(0, 8)
        : 0;
    // Preserve the current section when adopting the shorter guided setup.
    final step = json['setupVersion'] == 2
        ? savedStep.clamp(0, 7)
        : const [0, 2, 3, 3, 4, 5, 6, 6, 7][savedStep];
    return UiPreferences(
      appearance:
          AppAppearance.values
              .where((value) => value.name == json['appearance'])
              .firstOrNull ??
          AppAppearance.system,
      density:
          CatalogueDensity.values
              .where((value) => value.name == json['density'])
              .firstOrNull ??
          CatalogueDensity.comfortable,
      textScale: scale is num && textScales.contains(scale.toDouble())
          ? scale.toDouble()
          : 1,
      reduceMotion: json['reduceMotion'] == true,
      locale: json['locale'] is String ? json['locale'] as String : null,
      setupCompleted: json['setupCompleted'] == true,
      setupStep: step,
      gestures: json['gestures'] is Map<String, dynamic>
          ? GestureZones.fromJson(json['gestures'] as Map<String, dynamic>)
          : const GestureZones(),
    );
  }
}
