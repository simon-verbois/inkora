import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import 'settings_sections.dart';

/// The single settings search field, shared by the phone index and the wide
/// sidebar so both offer the same hint and matching.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.showIcon = true,
    this.fieldKey = const Key('settings-search'),
  });
  final Key fieldKey;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool showIcon;
  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    decoration: InputDecoration(
      prefixIcon: showIcon ? const Icon(InkIcons.magnifyingGlass) : null,
      hintText: context.tr('Search settings'),
    ),
    onChanged: onChanged,
  );
}

/// Group heading above a block of settings entries.
class SettingsGroupLabel extends StatelessWidget {
  const SettingsGroupLabel(this.group, {super.key});
  final SettingsGroup group;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      InkSpace.md,
      InkSpace.lg,
      InkSpace.md,
      InkSpace.sm,
    ),
    child: Semantics(
      header: true,
      child: LText(
        group.label,
        key: ValueKey('settings-group-${group.name}'),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

/// The settings menu: grouped entries, or a flat list of search results
/// whose [entry] receives the section's path ("Reading › Gestures").
List<Widget> settingsMenu(
  BuildContext context, {
  required String query,
  required Widget Function(SettingsSection section, String? path) entry,
}) {
  final strings = AppStrings.of(context);
  if (query.isNotEmpty) {
    final results = searchSettings(strings, query);
    if (results.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(InkSpace.lg),
          child: LText('No matching settings', key: Key('settings-no-results')),
        ),
      ];
    }
    return [
      for (final section in results)
        entry(section, settingsSectionPath(strings, section)),
    ];
  }
  return [
    for (final group in SettingsGroup.values) ...[
      SettingsGroupLabel(group),
      for (final section in settingsSections)
        if (section.group == group) entry(section, null),
    ],
  ];
}

/// One entry of the settings sidebar, also used by the setup step list so
/// both side panes share geometry and selection styling.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.leading,
    required this.title,
    required this.selected,
    this.subtitle,
    this.onTap,
  });
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Semantics(
      selected: selected,
      child: ListTile(
        minTileHeight: InkoraLayout.touchTarget,
        contentPadding: const EdgeInsets.symmetric(horizontal: InkSpace.md),
        shape: const RoundedRectangleBorder(borderRadius: InkRadius.medium),
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
        leading: leading,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    ),
  );
}
