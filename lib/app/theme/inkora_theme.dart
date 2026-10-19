import '../../features/settings/domain/ui_preferences.dart';
import 'appearance_palette.dart';
import 'horizontal_page_transitions.dart';

import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';

/// Shared geometry. Screens use these tokens rather than independent constants.
abstract final class InkoraLayout {
  static const double space = 12;
  static const double pagePadding = 16;
  static const double radius = 20;
  static const double touchTarget = 48;
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
  });
  final Color panel, raised, border, heading, success;

  static InkoraColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<InkoraColors>() ??
        InkoraColors(
          panel: theme.colorScheme.surface,
          raised: theme.colorScheme.surfaceContainerHighest,
          border: theme.colorScheme.outline,
          heading: theme.colorScheme.onSurface,
          success: theme.colorScheme.primary,
        );
  }

  @override
  InkoraColors copyWith({
    Color? panel,
    Color? raised,
    Color? border,
    Color? heading,
    Color? success,
  }) => InkoraColors(
    panel: panel ?? this.panel,
    raised: raised ?? this.raised,
    border: border ?? this.border,
    heading: heading ?? this.heading,
    success: success ?? this.success,
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
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(InkoraLayout.radius),
    );
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
          success: dark ? const Color(0xFFBADA8A) : const Color(0xFF386324),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkoraLayout.radius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkoraLayout.radius),
          borderSide: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: palette.button ?? action,
          foregroundColor: palette.onButton ?? onAction,
          shape: shape,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: .6),
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: amber,
        linearTrackColor: raised,
        borderRadius: BorderRadius.circular(6),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: raised,
        side: BorderSide(color: border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: shape,
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
