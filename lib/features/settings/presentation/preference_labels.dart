import '../../../reader/domain/gesture_zones.dart';
import '../domain/ui_preferences.dart';

String appearanceLabel(AppAppearance appearance) => switch (appearance) {
  AppAppearance.system => 'System',
  AppAppearance.light => 'Light',
  AppAppearance.dark => 'Dark',
  AppAppearance.amoled => 'AMOLED',
  AppAppearance.sepia => 'Sepia',
  AppAppearance.ocean => 'Ocean',
  AppAppearance.forest => 'Forest',
};
String densityLabel(CatalogueDensity density) => switch (density) {
  CatalogueDensity.comfortable => 'Comfortable',
  CatalogueDensity.compact => 'Compact',
};
String gesturePresetLabel(GesturePreset preset) => switch (preset) {
  GesturePreset.systemNavigation => 'Easy system back',
  GesturePreset.fullPage => 'Full-page gestures',
  GesturePreset.custom => 'Custom',
  GesturePreset.balanced => 'Balanced',
};
