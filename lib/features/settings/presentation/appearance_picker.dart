import 'package:flutter/material.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';
import '../../../app/theme/appearance_palette.dart';
import '../../../app/theme/inkora_theme.dart';
import '../domain/ui_preferences.dart';
import 'preference_labels.dart';
import 'settings_adaptive_layout.dart';

class AppearancePicker extends StatelessWidget {
  const AppearancePicker({
    super.key,
    required this.preferences,
    required this.onSelect,
    required this.onSystemLightSelect,
    required this.onSystemDarkSelect,
  });
  final UiPreferences preferences;
  final ValueChanged<AppAppearance>? onSelect;
  final ValueChanged<AppAppearance>? onSystemLightSelect, onSystemDarkSelect;

  @override
  Widget build(BuildContext context) {
    final automatic = preferences.appearance == AppAppearance.system;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('follow-system-theme'),
          contentPadding: EdgeInsets.zero,
          title: const LText('Follow system'),
          subtitle: const LText('Choose a theme for each system appearance.'),
          value: automatic,
          onChanged: onSelect == null
              ? null
              : (enabled) => onSelect!(
                  enabled
                      ? AppAppearance.system
                      : Theme.of(context).brightness == Brightness.dark
                      ? preferences.darkTheme
                      : preferences.lightTheme,
                ),
        ),
        const SizedBox(height: 16),
        SettingsColumns(
          first: _PaletteGroup(
            key: const Key('light-theme-group'),
            title: automatic ? 'Default light theme' : 'Light themes',
            light: true,
            selected: automatic
                ? preferences.lightTheme
                : preferences.appearance,
            onSelect: automatic ? onSystemLightSelect : onSelect,
          ),
          second: _PaletteGroup(
            key: const Key('dark-theme-group'),
            title: automatic ? 'Default dark theme' : 'Dark themes',
            light: false,
            selected: automatic
                ? preferences.darkTheme
                : preferences.appearance,
            onSelect: automatic ? onSystemDarkSelect : onSelect,
          ),
        ),
      ],
    );
  }
}

class _PaletteGroup extends StatelessWidget {
  const _PaletteGroup({
    super.key,
    required this.title,
    required this.light,
    required this.selected,
    required this.onSelect,
  });
  final String title;
  final bool light;
  final AppAppearance selected;
  final ValueChanged<AppAppearance>? onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LText(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = (bounds.maxWidth / (136 * scale)).floor().clamp(1, 4);
          final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final appearance in AppAppearance.values.where(
                (value) => light ? value.isLight : value.isDark,
              ))
                SizedBox(
                  width: width,
                  child: _PaletteTile(
                    appearance: appearance,
                    selected: selected == appearance,
                    onTap: onSelect == null
                        ? null
                        : () => onSelect!(appearance),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.appearance,
    required this.selected,
    required this.onTap,
  });
  final AppAppearance appearance;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: .08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: InkRadius.medium,
          side: BorderSide(
            color: selected ? scheme.primary : InkoraColors.of(context).border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme-${appearance.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: InkRadius.small,
                  child: SizedBox(
                    height: 48,
                    child: CustomPaint(painter: _ThemePreview(appearance)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LText(
                        appearanceLabel(appearance),
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: selected
                          ? Icon(
                              InkIcons.checkCircle,
                              size: 20,
                              color: scheme.primary,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends CustomPainter {
  const _ThemePreview(this.appearance);
  final AppAppearance appearance;
  @override
  void paint(Canvas canvas, Size size) {
    final palette = AppearancePalette.of(appearance);
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    void box(double x, double y, double w, double h, Color color) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * x,
              size.height * y,
              size.width * w,
              size.height * h,
            ),
            const Radius.circular(InkRadius.s),
          ),
          Paint()..color = color,
        );
    box(.06, .14, .88, .72, palette.panel);
    box(.1, .24, .2, .52, palette.raised);
    box(.36, .28, .48, .08, palette.accent);
    box(.36, .46, .35, .06, palette.accent.withValues(alpha: .55));
    box(.36, .64, .2, .12, palette.button ?? InkoraTheme.action);
  }

  @override
  bool shouldRepaint(_ThemePreview oldDelegate) =>
      oldDelegate.appearance != appearance;
}
