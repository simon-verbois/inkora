import '../../../app/widgets/ink_settings_section.dart';
import '../../../app/widgets/ink_slider.dart';
import '../../../app/widgets/ink_screen_header.dart';
import 'settings_transfer_panel.dart';
import 'about_content.dart';
import 'servers_screen.dart';
import '../../../app/l10n/app_strings.dart';
import 'language_settings.dart';
import 'settings_sections.dart';
import 'settings_navigation.dart';
import 'gesture_settings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../reader/data/reader_store.dart';
import '../../../reader/presentation/reader_settings_sheet.dart';
import '../../../offline/presentation/download_settings_panel.dart';
import '../../connection/application/session_controller.dart';
import '../application/ui_preferences_provider.dart';
import '../domain/ui_preferences.dart';
import 'appearance_picker.dart';
import 'library_defaults_screen.dart';
import 'image_enhancement_control.dart';
import 'settings_adaptive_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.section,
    this.embedded = false,
    this.onSaved,
    this.editorKey,
  });
  final GlobalKey<ReaderSettingsSheetState>? editorKey;
  final bool embedded;
  final VoidCallback? onSaved;
  final String? section;
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  String _query = '';
  Future<void> _save(UiPreferences Function(UiPreferences) change) async {
    setState(() => _saving = true);
    try {
      await (await ref.read(uiPreferencesStoreProvider)).update(change);
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to save appearance settings. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = SettingsPaneScope.wideOf(context);
    final section = widget.section ?? (wide ? 'servers' : null);
    if (section == 'servers') return const ServersScreen();
    if (section == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: const InkScreenHeader(title: LText('Settings')),
        body: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: CustomScrollView(
            key: const Key('settings-index-scroll'),
            slivers: [
              SliverFloatingHeader(
                animationStyle: MediaQuery.disableAnimationsOf(context)
                    ? AnimationStyle.noAnimation
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    InkScreenHeader.extent + 16,
                    16,
                    4,
                  ),
                  child: SettingsSearchField(
                    onChanged: (text) {
                      final query = text.toLowerCase().trim();
                      if (query != _query) setState(() => _query = query);
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: settingsMenu(
                    context,
                    query: _query,
                    entry: (entry, path) => InkSettingsRow(
                      key: ValueKey('settings-entry-${entry.id}'),
                      icon: entry.icon,
                      title: context.tr(entry.title),
                      subtitle: path ?? entry.description,
                      onTap: () => context.push('/settings/${entry.id}'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final data = ref.watch(uiPreferencesProvider);
    final preferences = data.asData?.value ?? const UiPreferences();
    if (section == 'reading') {
      return const LibraryDefaultsScreen();
    }
    if (section == 'reading-defaults' || section == 'quality') {
      final account = ref.watch(
        sessionProvider.select((state) => state.session?.accountId),
      );
      return Scaffold(
        // Categories have no page header beside the wide category pane, but
        // the Global defaults subpage keeps its title and Back there too.
        appBar: widget.embedded || (wide && section == 'quality')
            ? null
            : InkScreenHeader(
                title: LText(
                  section == 'quality'
                      ? settingsSectionTitle('quality')
                      : 'Global defaults',
                ),
              ),
        body: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: FutureBuilder(
            future: ref.watch(databaseProvider),
            builder: (context, snapshot) => snapshot.hasError
                ? const Center(
                    child: InkEmptyState(
                      icon: InkIcons.warningCircle,
                      title: 'Unable to open reading preferences.',
                    ),
                  )
                : !snapshot.hasData || account == null
                ? const Center(child: CircularProgressIndicator())
                : ReaderSettingsSheet(
                    key: widget.editorKey ?? ValueKey(account),

                    store: ReaderStore(snapshot.requireData, account),
                    qualityOnly: section == 'quality',
                    upscalingControls: section == 'quality'
                        ? const ImageEnhancementControl()
                        : null,
                    onSaved: widget.onSaved,
                  ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: widget.embedded || wide
          ? null
          : InkScreenHeader(title: LText(settingsSectionTitle(section))),
      body: InkContent(
        maxWidth: wide && (section == 'appearance' || section == 'gestures')
            ? 960
            : InkoraLayout.maxSettingsWidth,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (data.hasError)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LText(
                  'Saved appearance unavailable. Default settings are active.',
                ),
              ),
            if (section == 'appearance') ...[
              InkSettingsSection(
                first: true,
                title: 'Application theme',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppearancePicker(
                      preferences: preferences,
                      onSelect: _saving || !data.hasValue
                          ? null
                          : (value) => _save(
                              (current) => current.copyWith(appearance: value),
                            ),
                      onSystemLightSelect: _saving || !data.hasValue
                          ? null
                          : (value) => _save(
                              (current) =>
                                  current.copyWith(systemLightTheme: value),
                            ),
                      onSystemDarkSelect: _saving || !data.hasValue
                          ? null
                          : (value) => _save(
                              (current) =>
                                  current.copyWith(systemDarkTheme: value),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const LText(
                      'Reader backgrounds are configured separately in Reading.',
                    ),
                  ],
                ),
              ),
              InkSettingsSection(
                title: 'Libraries',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<bool>(
                      key: const Key('catalogue-layout'),
                      initialValue: preferences.catalogueListView,
                      decoration: InputDecoration(
                        labelText: context.tr('Layout'),
                      ),
                      isExpanded: true,
                      itemHeight: null,
                      items: const [
                        DropdownMenuItem(
                          value: false,
                          child: LText('Show grid'),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: LText('Show list'),
                        ),
                      ],
                      onChanged: _saving || !data.hasValue
                          ? null
                          : (value) {
                              if (value != null &&
                                  value != preferences.catalogueListView) {
                                _save(
                                  (p) => p.copyWith(catalogueListView: value),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    const LText('Home covers per row'),
                    const SizedBox(height: 16),
                    _HomeCoverCount(
                      key: const Key('home-portrait-columns'),
                      label: 'Portrait',
                      choices: const [2, 3, 4],
                      selected: preferences.homePortraitColumns,
                      onChanged: _saving || !data.hasValue
                          ? null
                          : (value) => _save(
                              (current) =>
                                  current.copyWith(homePortraitColumns: value),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _HomeCoverCount(
                      key: const Key('home-landscape-columns'),
                      label: 'Landscape',
                      choices: const [5, 6, 7],
                      selected: preferences.homeLandscapeColumns,
                      onChanged: _saving || !data.hasValue
                          ? null
                          : (value) => _save(
                              (current) =>
                                  current.copyWith(homeLandscapeColumns: value),
                            ),
                    ),
                    const SizedBox(height: 16),
                    if (!widget.embedded)
                      SwitchListTile.adaptive(
                        key: const Key('hide-tags'),
                        contentPadding: EdgeInsets.zero,
                        title: const LText('Hide tags'),
                        value: preferences.hideTags,
                        onChanged: _saving || !data.hasValue
                            ? null
                            : (value) => _save(
                                (current) => current.copyWith(hideTags: value),
                              ),
                      ),
                  ],
                ),
              ),
            ],
            if (section == 'gestures')
              GestureSettings(showTitle: widget.embedded && !wide),
            if (section == 'language')
              LanguageSettings(showTitle: widget.embedded && !wide),
            if (section == 'transfer') const SettingsTransferPanel(),
            if (section == 'downloads') const DownloadSettingsPanel(),
            if (section == 'accessibility')
              InkSettingsSection(
                first: true,
                title: "Reading comfort",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkSlider(
                      sliderKey: const Key('interface-text-scale'),
                      label: context.tr('Interface text size'),
                      value: preferences.textScale,
                      min: UiPreferences.minTextScale,
                      max: UiPreferences.maxTextScale,
                      divisions: 9,
                      enabled: !_saving,
                      formatValue: (value) =>
                          context.tr('{0} %', [(value * 100).round()]),
                      onCommitted: (value) => _save(
                        (current) => current.copyWith(textScale: value),
                      ),
                    ),
                    const LText(
                      'Applied in addition to your device text size.',
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const LText('Reduce motion'),
                      subtitle: const LText(
                        'Disable theme and navigation transition animations.',
                      ),
                      value: preferences.reduceMotion,
                      onChanged: _saving
                          ? null
                          : (value) => _save(
                              (current) =>
                                  current.copyWith(reduceMotion: value),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const LText(
                      'Navigation uses labels and icons. Reading controls appear on a single tap.',
                    ),
                  ],
                ),
              ),
            if (section == 'about') const AboutContent(),
          ],
        ),
      ),
    );
  }
}

class _HomeCoverCount extends StatelessWidget {
  const _HomeCoverCount({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final List<int> choices;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey(('home-cover-count', label, selected)),
    initialValue: selected,
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: context.tr(label)),
    items: [
      for (final value in choices)
        DropdownMenuItem(value: value, child: Text('$value')),
    ],
    onChanged: onChanged == null
        ? null
        : (value) {
            if (value != null && value != selected) onChanged!(value);
          },
  );
}
