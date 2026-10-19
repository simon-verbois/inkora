import '../../../app/icons/inkora_icons.dart';

/// Shared navigation catalogue for settings search and the first-run tour.
const settingsSections = [
  (
    'servers',
    'Servers and account',
    'Manage connections and choose your active server',
    InkIcons.books,
  ),
  (
    'language',
    'Language',
    'Application language and system preferences',
    InkIcons.gearSix,
  ),
  ('appearance', 'Appearance', 'Theme and catalogue density', InkIcons.palette),
  (
    'reading',
    'Reading',
    'Profiles, direction and page layout',
    InkIcons.bookOpen,
  ),
  (
    'gestures',
    'Reading gestures',
    'Swipe areas and system back edges',
    InkIcons.slidersHorizontal,
  ),
  (
    'quality',
    'Quality',
    'Image rendering and format preferences',
    InkIcons.slidersHorizontal,
  ),
  ('downloads', 'Downloads', 'Storage and network', InkIcons.downloadSimple),
  (
    'accessibility',
    'Accessibility',
    'Text size and reduced motion',
    InkIcons.personArmsSpread,
  ),
  (
    'transfer',
    'Import / export',
    'Transfer settings and bookmarks',
    InkIcons.arrowsLeftRight,
  ),
  ('about', 'About Inkora', 'Version and open-source licenses', InkIcons.info),
];
