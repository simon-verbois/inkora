import 'package:flutter/material.dart';

import '../../features/settings/domain/ui_preferences.dart';

/// Shared immutable tokens keep previews and application themes identical.
class AppearancePalette {
  const AppearancePalette(
    this.background,
    this.panel,
    this.raised,
    this.accent, {
    this.button,
    this.onButton,
    this.heading,
  });
  final Color background, panel, raised, accent;
  final Color? button, onButton, heading;

  /// Badge/control fill over cover artwork and reader pages, in every
  /// appearance (artwork colours do not follow the application theme).
  static const scrim = Color(0xB8000000);
  static const onScrim = Colors.white;

  /// Modal barrier behind sheets and dialogs.
  static const barrier = Color(0x8A000000);

  /// Bookmark highlight drawn on EPUB/PDF pages, independent of appearance.
  static const readerHighlight = Color(0xFFD39A32);
  static const readerHighlightLine = Color(0xFFB47D20);

  /// Read/completed state and positive confirmation.
  Color success(bool dark) =>
      dark ? const Color(0xFFBADA8A) : const Color(0xFF386324);

  /// Destructive actions and failures.
  Color danger(bool dark) =>
      dark ? const Color(0xFFFFB4AB) : const Color(0xFFA4221A);

  static AppearancePalette of(AppAppearance appearance) => switch (appearance) {
    AppAppearance.system || AppAppearance.light => const AppearancePalette(
      Color(0xFFFBF6ED),
      Color(0xFFFFFAF2),
      Color(0xFFF1EADF),
      Color(0xFF9C4700),
    ),
    AppAppearance.dark => const AppearancePalette(
      Color(0xFF0D1115),
      Color(0xFF151A20),
      Color(0xFF20272F),
      Color(0xFFFFAD45),
    ),
    AppAppearance.amoled => const AppearancePalette(
      Colors.black,
      Color(0xFF151A20),
      Color(0xFF20272F),
      Color(0xFFFFAD45),
    ),
    AppAppearance.sepia => const AppearancePalette(
      Color(0xFFF0E3CA),
      Color(0xFFF8EDD9),
      Color(0xFFE4D4B7),
      Color(0xFF8C3D00),
    ),
    AppAppearance.ocean => const AppearancePalette(
      Color(0xFF071B2B),
      Color(0xFF102A3D),
      Color(0xFF1A394E),
      Color(0xFFFFAD45),
    ),
    AppAppearance.forest => const AppearancePalette(
      Color(0xFF0C1C16),
      Color(0xFF162D23),
      Color(0xFF234234),
      Color(0xFFFFAD45),
    ),
    AppAppearance.pearl => const AppearancePalette(
      Color(0xFFEFF3F8),
      Colors.white,
      Color(0xFFE2EAF3),
      Color(0xFF1D4F80),
      button: Color(0xFF1D4F80),
      onButton: Colors.white,
      heading: Color(0xFF133D64),
    ),
    AppAppearance.rose => const AppearancePalette(
      Color(0xFFFFF0F2),
      Color(0xFFFFF8F9),
      Color(0xFFF2DDE3),
      Color(0xFF8C2C53),
      button: Color(0xFF8C2C53),
      onButton: Colors.white,
      heading: Color(0xFF6D2442),
    ),
    AppAppearance.midnight => const AppearancePalette(
      Color(0xFF101329),
      Color(0xFF191F3D),
      Color(0xFF293354),
      Color(0xFFAFC3FF),
      button: Color(0xFFAFC3FF),
      onButton: Color(0xFF14182B),
      heading: Color(0xFFDCE3FF),
    ),
    AppAppearance.plum => const AppearancePalette(
      Color(0xFF211329),
      Color(0xFF2D1C37),
      Color(0xFF43294F),
      Color(0xFFE9B3F5),
      button: Color(0xFFE9B3F5),
      onButton: Color(0xFF26132C),
      heading: Color(0xFFF4D7FA),
    ),
  };
}
