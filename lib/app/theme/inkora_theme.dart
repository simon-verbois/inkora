import '../../features/settings/domain/ui_preferences.dart';
import 'appearance_palette.dart';
import 'horizontal_page_transitions.dart';

import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';

/// Spacing scale (multiples of 4). Odd historical values (6, 10, 20) round to
/// the nearest step; see docs/design/UI_STANDARDS.md.
abstract final class InkSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Four corner radii: covers/badges [s], tiles/menus [m], panels/sheets [l],
/// chips/buttons [pill].
abstract final class InkRadius {
  static const double s = 6;
  static const double m = 12;
  static const double l = 20;
  static const double pill = 999;
  static const small = BorderRadius.all(Radius.circular(s));
  static const medium = BorderRadius.all(Radius.circular(m));
  static const large = BorderRadius.all(Radius.circular(l));
  static const round = BorderRadius.all(Radius.circular(pill));
}

/// Type roles over the Material text theme. Widgets pick a role instead of an
/// inline font size or weight.
extension InkTextRoles on TextTheme {
  /// Screen and detail-page titles.
  TextStyle? get screenTitle => headlineSmall;

  /// Section and panel headings.
  TextStyle? get sectionTitle =>
      titleMedium?.copyWith(fontWeight: FontWeight.w700);

  /// Sheet and dialog titles.
  TextStyle? get sheetTitle => titleLarge;

  /// Running text.
  TextStyle? get body => bodyMedium;

  /// Metadata and progress lines.
  TextStyle? get meta => bodySmall;
}

/// Shared geometry. Screens use these tokens rather than independent constants.
abstract final class InkoraLayout {
  static const double radius = InkRadius.l;
  static const double touchTarget = 48;

  /// Painted button/chip height; Material keeps a separate 48 dp hit region.
  /// A minimum rather than a fixed height lets scaled labels grow.
  static const double controlHeight = 40;
  static const double maxContentWidth = 1200;
  static const double maxSettingsWidth = 760;
  static const double coverRatio = 0.7;
}

@immutable
class InkoraColors extends ThemeExtension<InkoraColors> {
  const InkoraColors({
    required this.panel,
    required this.raised,
    required this.border,
    required this.heading,
    required this.success,
    required this.danger,
    required this.scrim,
    required this.onScrim,
  });
  final Color panel, raised, border, heading;

  /// Completed/read state and positive confirmation.
  final Color success;

  /// Destructive actions and failures.
  final Color danger;

  /// Overlay fill for badges and controls drawn over cover artwork or reader
  /// pages; [onScrim] is its foreground. Artwork is theme independent, so the
  /// scrim stays dark in every appearance.
  final Color scrim, onScrim;

  static InkoraColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<InkoraColors>() ??
        InkoraColors(
          panel: theme.colorScheme.surface,
          raised: theme.colorScheme.surfaceContainerHighest,
          border: theme.colorScheme.outline,
          heading: theme.colorScheme.onSurface,
          success: theme.colorScheme.primary,
          danger: theme.colorScheme.error,
          scrim: AppearancePalette.scrim,
          onScrim: AppearancePalette.onScrim,
        );
  }

  @override
  InkoraColors copyWith({
    Color? panel,
    Color? raised,
    Color? border,
    Color? heading,
    Color? success,
    Color? danger,
    Color? scrim,
    Color? onScrim,
  }) => InkoraColors(
    panel: panel ?? this.panel,
    raised: raised ?? this.raised,
    border: border ?? this.border,
    heading: heading ?? this.heading,
    success: success ?? this.success,
    danger: danger ?? this.danger,
    scrim: scrim ?? this.scrim,
    onScrim: onScrim ?? this.onScrim,
  );

  @override
  InkoraColors lerp(InkoraColors? other, double t) => other == null
      ? this
      : InkoraColors(
          panel: Color.lerp(panel, other.panel, t)!,
          raised: Color.lerp(raised, other.raised, t)!,
          border: Color.lerp(border, other.border, t)!,
          heading: Color.lerp(heading, other.heading, t)!,
          success: Color.lerp(success, other.success, t)!,
          danger: Color.lerp(danger, other.danger, t)!,
          scrim: Color.lerp(scrim, other.scrim, t)!,
          onScrim: Color.lerp(onScrim, other.onScrim, t)!,
        );
}

abstract final class InkoraTheme {
  static const lightBrand = Color(0xFFD56A00);
  static const action = Color(0xFFFF9A2F);
  static const onAction = Color(0xFF21180E);
  static ThemeData light() => forAppearance(AppAppearance.light);
  static ThemeData dark({bool amoled = false}) =>
      forAppearance(amoled ? AppAppearance.amoled : AppAppearance.dark);
  static ThemeData sepia() => forAppearance(AppAppearance.sepia);
  static ThemeData ocean() => forAppearance(AppAppearance.ocean);
  static ThemeData forest() => forAppearance(AppAppearance.forest);

  static ThemeData forAppearance(AppAppearance appearance) {
    final palette = AppearancePalette.of(appearance);
    final dark = appearance.isDark;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final background = palette.background;
    final panel = palette.panel;
    final raised = palette.raised;
    final text = dark ? const Color(0xFFF5EFE4) : const Color(0xFF242221);
    final secondary = dark ? const Color(0xFFBBC3CC) : const Color(0xFF625C55);
    final amber = palette.accent;
    final border = dark ? const Color(0xFF49535F) : const Color(0xFFBFAE95);
    final danger = palette.danger(dark);
    final scheme =
        ColorScheme.fromSeed(seedColor: amber, brightness: brightness).copyWith(
          primary: amber,
          onPrimary: dark ? const Color(0xFF251600) : Colors.white,
          surface: panel,
          surfaceContainerLowest: background,
          surfaceContainerLow: panel,
          surfaceContainer: panel,
          surfaceContainerHigh: raised,
          onSurface: text,
          onSurfaceVariant: secondary,
          outline: border,
          surfaceContainerHighest: raised,
          error: danger,
          onError: dark ? const Color(0xFF3B0907) : Colors.white,
        );
    const shape = RoundedRectangleBorder(borderRadius: InkRadius.large);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: panel,
      visualDensity: VisualDensity.standard,
      extensions: [
        InkoraColors(
          panel: panel,
          raised: raised,
          border: border,
          heading:
              palette.heading ??
              (dark ? const Color(0xFFFFD98E) : const Color(0xFF613B14)),
          success: palette.success(dark),
          danger: danger,
          scrim: AppearancePalette.scrim,
          onScrim: AppearancePalette.onScrim,
        ),
      ],
    );
    return base.copyWith(
      // Android keeps full-size pages during horizontal and edge navigation.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          ...const PageTransitionsTheme().builders,
          TargetPlatform.android: const HorizontalPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(InkIcons.caretLeft),
        closeButtonIconBuilder: (_) => const Icon(InkIcons.x),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: const OutlineInputBorder(borderRadius: InkRadius.large),
        enabledBorder: OutlineInputBorder(
          borderRadius: InkRadius.large,
          borderSide: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, InkoraLayout.controlHeight),
          backgroundColor: palette.button ?? action,
          foregroundColor: palette.onButton ?? onAction,
          shape: const StadiumBorder(),
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, InkoraLayout.controlHeight),
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, InkoraLayout.controlHeight),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(InkoraLayout.controlHeight),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: AppearancePalette.barrier,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(InkRadius.l),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: .6),
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: amber,
        linearTrackColor: raised,
        borderRadius: InkRadius.small,
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.all(InkSpace.xs),
        labelPadding: const EdgeInsets.symmetric(
          horizontal: InkSpace.sm,
          vertical: InkSpace.xs,
        ),
        backgroundColor: raised,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: InkRadius.medium),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(color: text),
        actionTextColor: amber,
      ),
      tooltipTheme: const TooltipThemeData(preferBelow: false),
    );
  }
}
