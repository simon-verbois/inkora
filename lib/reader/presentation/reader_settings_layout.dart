export '../../app/widgets/ink_slider.dart';

import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';
import '../../app/theme/inkora_theme.dart';
import '../domain/reading_settings.dart';
import 'reading_colors.dart';

/// Two aligned columns when labels have enough space; one at large text sizes.
/// Shared by document typography, page layout and image-format controls.
class ReaderSettingsGrid extends StatelessWidget {
  const ReaderSettingsGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 520 * scale ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// A labelled single-choice group of chips: the reader preference control
/// that replaces dropdowns. Chips wrap at large text sizes and narrow widths
/// instead of truncating; every choice stays visible and applies on tap.
class ReaderChoiceGroup extends StatelessWidget {
  const ReaderChoiceGroup({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onSelected,
    required this.id,
    this.wrapLabels = false,
  });

  /// Source message of the group heading.
  final String label;

  /// Choice identifiers mapped to their source message labels.
  final Map<String, String> choices;
  final String selected;
  final ValueChanged<String>? onSelected;

  /// Stable key prefix: each chip is keyed `reader-choice-$id-$choice`.
  final String id;
  final bool wrapLabels;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: LText(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: InkSpace.sm),
      if (wrapLabels)
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null && value != selected) onSelected?.call(value);
          },
          child: Column(
            children: [
              for (final choice in choices.entries)
                RadioListTile<String>(
                  key: Key('reader-choice-$id-${choice.key}'),
                  value: choice.key,
                  selected: choice.key == selected,
                  enabled: onSelected != null,
                  contentPadding: EdgeInsets.zero,
                  title: LText(choice.value, softWrap: true),
                ),
            ],
          ),
        )
      else
        Wrap(
          spacing: InkSpace.sm,
          runSpacing: InkSpace.sm,
          children: [
            for (final choice in choices.entries)
              ChoiceChip(
                key: Key('reader-choice-$id-${choice.key}'),
                showCheckmark: false,
                label: LText(choice.value),
                selected: choice.key == selected,
                onSelected: onSelected == null
                    ? null
                    : (_) {
                        if (choice.key != selected) onSelected!(choice.key);
                      },
              ),
          ],
        ),
    ],
  );
}

/// Reader background swatches: a colour sample with its name underneath.
class ReaderBackgroundSwatches extends StatelessWidget {
  const ReaderBackgroundSwatches({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.onCustom,
    this.customSelected = false,
  });
  final VoidCallback? onCustom;
  final bool customSelected;
  final Map<ReadingBackground, String> choices;
  final ReadingBackground? selected;
  final ValueChanged<ReadingBackground>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: LText(
            'Background',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: InkSpace.sm),
        Wrap(
          spacing: InkSpace.sm,
          runSpacing: InkSpace.sm,
          children: [
            for (final choice in choices.entries)
              Semantics(
                button: true,
                selected: choice.key == selected,
                label: context.tr(choice.value),
                excludeSemantics: true,
                child: InkWell(
                  key: Key('reader-background-${choice.key.name}'),
                  borderRadius: InkRadius.medium,
                  onTap: onSelected == null || choice.key == selected
                      ? null
                      : () => onSelected!(choice.key),
                  child: SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: InkSpace.xs,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: choice.key.paperColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: choice.key == selected
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                width: choice.key == selected ? 3 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: InkSpace.xs),
                          LText(
                            choice.value,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (onCustom != null)
              Semantics(
                button: true,
                selected: customSelected,
                label: context.tr('Custom colors'),
                excludeSemantics: true,
                child: InkWell(
                  key: const Key('reader-background-custom'),
                  borderRadius: InkRadius.medium,
                  onTap: onCustom,
                  child: SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: InkSpace.xs,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Color(0xffe53935),
                                  Color(0xffffc107),
                                  Color(0xff43a047),
                                  Color(0xff00acc1),
                                  Color(0xff3949ab),
                                  Color(0xff8e24aa),
                                  Color(0xffe53935),
                                ],
                              ),
                              border: Border.all(
                                color: customSelected
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                width: customSelected ? 3 : 1,
                              ),
                            ),
                            child: customSelected
                                ? const Icon(
                                    InkIcons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(height: InkSpace.xs),
                          LText(
                            'Custom',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
