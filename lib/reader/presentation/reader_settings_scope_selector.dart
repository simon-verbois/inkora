import 'package:flutter/material.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/theme/inkora_theme.dart';
import '../domain/reading_settings.dart';

/// Compact editing-target selector shared by modal and embedded headers.
class ReaderSettingsScopeSelector extends StatelessWidget {
  const ReaderSettingsScopeSelector({
    super.key,
    required this.scope,
    required this.choices,
    this.onSelected,
  });
  final SettingsScope? scope;
  final Map<SettingsScope, String> choices;
  final ValueChanged<SettingsScope>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (scope == null) return const SizedBox.shrink();
    return PopupMenuButton<SettingsScope>(
      key: const Key('reader-settings-scope'),
      tooltip: context.tr('Reading preferences'),
      enabled: onSelected != null,
      position: PopupMenuPosition.over,
      useRootNavigator: true,
      itemBuilder: (_) => [
        for (final choice in choices.entries)
          CheckedPopupMenuItem(
            key: Key('reader-choice-scope-${choice.key.name}'),
            value: choice.key,
            checked: choice.key == scope,
            child: LText(choice.value),
          ),
      ],
      onSelected: (value) {
        if (value != scope) onSelected?.call(value);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: InkRadius.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: LText(choices[scope]!)),
                if (choices.length > 1) ...[
                  const SizedBox(width: 8),
                  const Icon(InkIcons.caretDown, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
