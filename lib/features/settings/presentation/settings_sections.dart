import 'package:flutter/widgets.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';

/// The four settings groups, in menu order.
enum SettingsGroup {
  account('Account'),
  reading('Reading'),
  application('Application'),
  data('Data');

  const SettingsGroup(this.label);

  /// Source message of the group label.
  final String label;
}

/// One settings page: its route [id], menu/page [title] (the page header uses
/// the same message), search [description], distinct [icon] and [group].
@immutable
final class SettingsSection {
  const SettingsSection(
    this.id,
    this.title,
    this.description,
    this.icon,
    this.group,
  );
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final SettingsGroup group;
}

/// Shared navigation catalogue for the settings index, the wide sidebar and
/// search. Grouped in [SettingsGroup] order.
const settingsSections = [
  SettingsSection(
    'servers',
    'Servers and account',
    'Manage connections and choose your active server',
    InkIcons.hardDrives,
    SettingsGroup.account,
  ),
  SettingsSection(
    'reading',
    'Reading profiles',
    'Profiles, direction and page layout',
    InkIcons.bookOpen,
    SettingsGroup.reading,
  ),
  SettingsSection(
    'gestures',
    'Gestures',
    'Swipe areas and system back edges',
    InkIcons.hand,
    SettingsGroup.reading,
  ),
  SettingsSection(
    'quality',
    'Image quality',
    'Image rendering and format preferences',
    InkIcons.image,
    SettingsGroup.reading,
  ),
  SettingsSection(
    'appearance',
    'Appearance',
    'Theme and home covers',
    InkIcons.palette,
    SettingsGroup.application,
  ),
  SettingsSection(
    'language',
    'Language',
    'Application language and system preferences',
    InkIcons.globe,
    SettingsGroup.application,
  ),
  SettingsSection(
    'accessibility',
    'Accessibility',
    'Text size and reduced motion',
    InkIcons.personArmsSpread,
    SettingsGroup.application,
  ),
  SettingsSection(
    'downloads',
    'Downloads',
    'Storage and network',
    InkIcons.downloadSimple,
    SettingsGroup.application,
  ),
  SettingsSection(
    'transfer',
    'Import / export',
    'Transfer settings and bookmarks',
    InkIcons.arrowsDownUp,
    SettingsGroup.data,
  ),
  SettingsSection(
    'about',
    'About Inkora',
    'Version and open-source licenses',
    InkIcons.info,
    SettingsGroup.data,
  ),
];

/// Page title of a settings section id (falls back to Settings).
String settingsSectionTitle(String id) =>
    settingsSections.where((s) => s.id == id).firstOrNull?.title ?? 'Settings';

/// "Reading › Gestures": the location shown with a search result.
String settingsSectionPath(AppStrings strings, SettingsSection section) =>
    strings.text('{0} › {1}', [
      strings.text(section.group.label),
      strings.text(section.title),
    ]);

/// Sections whose localized title, group or description contains [query]
/// (already lower-cased and trimmed). An empty query matches everything.
List<SettingsSection> searchSettings(AppStrings strings, String query) => [
  for (final section in settingsSections)
    if (query.isEmpty ||
        [
          section.title,
          section.description,
          section.group.label,
        ].any((text) => strings.text(text).toLowerCase().contains(query)))
      section,
];
