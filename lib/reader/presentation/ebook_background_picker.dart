import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../domain/reading_settings.dart';
import 'reading_colors.dart';

/// Matches the adjacent anchored font list; custom colors keep their editor.
class EbookBackgroundPicker extends StatelessWidget {
  const EbookBackgroundPicker({
    super.key,
    required this.settings,
    required this.onSelected,
    required this.onCustom,
  });
  final ReadingSettings settings;
  final ValueChanged<ReadingBackground>? onSelected;
  final VoidCallback? onCustom;

  static const choices = {
    ReadingBackground.white: 'White',
    ReadingBackground.sepia: 'Sepia',
    ReadingBackground.gray: 'Gray',
    ReadingBackground.slate: 'Night',
    ReadingBackground.black: 'Black',
  };

  Widget _sample(BuildContext context, ReadingBackground? value) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: value?.paperColor,
      shape: BoxShape.circle,
      gradient: value == null
          ? const SweepGradient(
              colors: [
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            )
          : null,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
  );

  Widget _label(BuildContext context, ReadingBackground? value) => Row(
    children: [
      _sample(context, value),
      const SizedBox(width: 8),
      Expanded(
        child: LText(
          value == null ? 'Custom' : choices[value]!,
          softWrap: true,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(bounds.maxWidth, 340.0);
      final selected = settings.ebook.customColors
          ? null
          : settings.background.current;
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: width,
          child: PopupMenuButton<String>(
            key: const Key('ebook-background-picker'),
            enabled: onSelected != null,
            tooltip: context.tr('Background'),
            position: PopupMenuPosition.under,
            useRootNavigator: true,
            constraints: BoxConstraints(
              minWidth: math.min(240, MediaQuery.sizeOf(context).width - 32),
              maxWidth: math.min(340, MediaQuery.sizeOf(context).width - 32),
              maxHeight: math.min(320, MediaQuery.sizeOf(context).height * .45),
            ),
            onSelected: (id) {
              if (id == 'custom') {
                onCustom?.call();
              } else {
                final value = ReadingBackground.values.byName(id);
                if (selected != value) onSelected?.call(value);
              }
            },
            itemBuilder: (context) => [
              for (final choice in choices.keys)
                CheckedPopupMenuItem(
                  value: choice.name,
                  checked: choice == selected,
                  key: Key('reader-background-${choice.name}'),
                  child: _label(context, choice),
                ),
              CheckedPopupMenuItem(
                value: 'custom',
                checked: selected == null,
                key: const Key('reader-background-custom'),
                child: _label(context, null),
              ),
            ],
            child: Semantics(
              button: true,
              child: InputDecorator(
                decoration: InputDecoration(
                  label: LText('Background', softWrap: true),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LText(
                        selected == null ? 'Custom' : choices[selected]!,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(InkIcons.caretDown, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
