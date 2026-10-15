import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';

import '../../../app/theme/inkora_theme.dart';
import '../domain/ui_preferences.dart';
import 'preference_labels.dart';

class AppearancePicker extends StatelessWidget {
  const AppearancePicker({
    super.key,
    required this.preferences,
    required this.onSelect,
  });
  final UiPreferences preferences;
  final ValueChanged<AppAppearance>? onSelect;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilterChip(
        label: const LText('Follow system'),
        avatar: const Icon(InkIcons.circleHalf, size: 18),
        selected: preferences.appearance == AppAppearance.system,
        onSelected: onSelect == null
            ? null
            : (_) => onSelect!(AppAppearance.system),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 480 ? 3 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final appearance in AppAppearance.values.skip(1))
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: preferences.appearance == appearance,
                    button: true,
                    child: InkWell(
                      key: ValueKey('theme-${appearance.name}'),
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(appearance),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: preferences.appearance == appearance
                                    ? 2
                                    : 1,
                                color: preferences.appearance == appearance
                                    ? Theme.of(context).colorScheme.primary
                                    : InkoraColors.of(context).border,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CustomPaint(
                                painter: _ThemePreview(appearance),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LText(
                            appearanceLabel(appearance),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ThemePreview extends CustomPainter {
  _ThemePreview(this.appearance);
  final AppAppearance appearance;
  @override
  void paint(Canvas canvas, Size size) {
    final light =
        appearance == AppAppearance.light || appearance == AppAppearance.sepia;
    final base = switch (appearance) {
      AppAppearance.sepia => const Color(0xFFF0E3CA),
      AppAppearance.ocean => const Color(0xFF071B2B),
      AppAppearance.forest => const Color(0xFF0C1C16),
      AppAppearance.amoled => Colors.black,
      AppAppearance.light => const Color(0xFFFBF6ED),
      _ => const Color(0xFF0D1115),
    };
    final panel = switch (appearance) {
      AppAppearance.sepia => const Color(0xFFE4D4B7),
      AppAppearance.ocean => const Color(0xFF1A394E),
      AppAppearance.forest => const Color(0xFF234234),
      _ => light ? const Color(0xFFE9DFCE) : const Color(0xFF27313D),
    };
    final accent = appearance == AppAppearance.sepia
        ? const Color(0xFF8C3D00)
        : light
        ? const Color(0xFF9C4700)
        : const Color(0xFFFFAD45);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    void box(double x, double y, double w, double h, Color color) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * x,
              size.height * y,
              size.width * w,
              size.height * h,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = color,
        );
    box(.08, .1, .45, .04, accent);
    box(.08, .24, .84, .22, panel);
    box(.12, .28, .16, .14, accent.withValues(alpha: .6));
    box(.34, .29, .5, .03, accent);
    box(.34, .36, .35, .02, base);
    box(.08, .53, .84, .03, accent.withValues(alpha: .6));
    for (var i = 0; i < 3; i++) {
      box(.08 + i * .29, .62, .24, .24, panel);
    }
    box(.08, .92, .84, .02, panel);
  }

  @override
  bool shouldRepaint(_ThemePreview oldDelegate) =>
      oldDelegate.appearance != appearance;
}
