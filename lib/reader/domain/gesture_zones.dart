enum GesturePreset { systemNavigation, balanced, fullPage, custom }

/// Device-owned logical-pixel bands that do not intercept reader gestures.
final class GestureZones {
  const GestureZones({
    this.preset = GesturePreset.balanced,
    this.left = 16,
    this.right = 16,
    this.top = 0,
    this.bottom = 0,
    this.showSystemBars = false,
  });
  final GesturePreset preset;
  final double left, right, top, bottom;
  final bool showSystemBars;
  @override
  bool operator ==(Object other) =>
      other is GestureZones &&
      preset == other.preset &&
      left == other.left &&
      right == other.right &&
      top == other.top &&
      bottom == other.bottom &&
      showSystemBars == other.showSystemBars;
  @override
  int get hashCode =>
      Object.hash(preset, left, right, top, bottom, showSystemBars);
  factory GestureZones.forPreset(GesturePreset preset) => switch (preset) {
    GesturePreset.systemNavigation => const GestureZones(
      preset: GesturePreset.systemNavigation,
      left: 32,
      right: 32,
      bottom: 24,
      showSystemBars: true,
    ),
    GesturePreset.fullPage => const GestureZones(
      preset: GesturePreset.fullPage,
      left: 0,
      right: 0,
    ),
    _ => const GestureZones(),
  };
  GestureZones copyWith({
    double? left,
    double? right,
    double? top,
    double? bottom,
    bool? showSystemBars,
  }) => GestureZones(
    preset: GesturePreset.custom,
    left: left ?? this.left,
    right: right ?? this.right,
    top: top ?? this.top,
    bottom: bottom ?? this.bottom,
    showSystemBars: showSystemBars ?? this.showSystemBars,
  );
  Map<String, Object> toJson() => {
    'preset': preset.name,
    'left': left,
    'right': right,
    'top': top,
    'bottom': bottom,
    'showSystemBars': showSystemBars,
  };
  factory GestureZones.fromJson(Map<String, dynamic> json) {
    double edge(String name, double fallback) {
      final value = json[name];
      return value is num && value.isFinite && value >= 0 && value <= 96
          ? value.toDouble()
          : fallback;
    }

    final preset =
        GesturePreset.values
            .where((p) => p.name == json['preset'])
            .firstOrNull ??
        GesturePreset.balanced;
    final base = GestureZones.forPreset(preset);
    return GestureZones(
      preset: preset,
      left: edge('left', base.left),
      right: edge('right', base.right),
      top: edge('top', base.top),
      bottom: edge('bottom', base.bottom),
      showSystemBars: json['showSystemBars'] is bool
          ? json['showSystemBars'] as bool
          : base.showSystemBars,
    );
  }
}
