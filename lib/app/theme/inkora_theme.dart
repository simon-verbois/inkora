import 'horizontal_page_transitions.dart';

import 'package:flutter/material.dart';

import '../icons/inkora_icons.dart';

/// Shared geometry. Screens use these tokens rather than independent constants.
abstract final class InkoraLayout {
  static const double space = 12;
  static const double pagePadding = 16;
  static const double radius = 10;
  static const double touchTarget = 48;
  static const double railBreakpoint = 840;
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
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark({bool amoled = false}) =>
      _build(Brightness.dark, amoled: amoled);

  static ThemeData sepia() => _build(
    Brightness.light,
    backgroundOverride: const Color(0xFFF0E3CA),
    panelOverride: const Color(0xFFF8EDD9),
    raisedOverride: const Color(0xFFE4D4B7),
    accentOverride: const Color(0xFF8C3D00),
  );
  static ThemeData ocean() => _build(
    Brightness.dark,
    backgroundOverride: const Color(0xFF071B2B),
    panelOverride: const Color(0xFF102A3D),
    raisedOverride: const Color(0xFF1A394E),
  );
  static ThemeData forest() => _build(
    Brightness.dark,
    backgroundOverride: const Color(0xFF0C1C16),
    panelOverride: const Color(0xFF162D23),
    raisedOverride: const Color(0xFF234234),
  );

  static ThemeData _build(
    Brightness brightness, {
    bool amoled = false,
    Color? backgroundOverride,
    Color? panelOverride,
    Color? raisedOverride,
    Color? accentOverride,
  }) {
    final dark = brightness == Brightness.dark;
    final background =
        backgroundOverride ??
        (dark
            ? (amoled ? Colors.black : const Color(0xFF0D1115))
            : const Color(0xFFFBF6ED));
    final panel =
        panelOverride ??
        (dark ? const Color(0xFF151A20) : const Color(0xFFFFFAF2));
    final raised =
        raisedOverride ??
        (dark ? const Color(0xFF20272F) : const Color(0xFFF1EADF));
    final text = dark ? const Color(0xFFF5EFE4) : const Color(0xFF242221);
    final secondary = dark ? const Color(0xFFBBC3CC) : const Color(0xFF625C55);
    final amber =
        accentOverride ??
        (dark ? const Color(0xFFFFAD45) : const Color(0xFF9C4700));
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
          heading: dark ? const Color(0xFFFFD98E) : const Color(0xFF613B14),
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
          backgroundColor: action,
          foregroundColor: onAction,
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
