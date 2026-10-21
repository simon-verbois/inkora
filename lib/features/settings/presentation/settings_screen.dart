import '../../../app/widgets/ink_screen_header.dart';
import 'settings_transfer_panel.dart';
import '../../../app/widgets/ink_slider.dart';
import 'about_content.dart';
import 'preference_labels.dart';
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
    final data = ref.watch(uiPreferencesProvider);
    final preferences = data.asData?.value ?? const UiPreferences();
    final wide = SettingsPaneScope.wideOf(context);
    final section = widget.section ?? (wide ? 'appearance' : null);
    if (section == null) {
      final host = ref.watch(
        sessionProvider.select((state) => state.session?.endpoint.uri.host),
      );
      String? value(SettingsSection entry) => switch (entry.id) {
        'servers' => host,
        'appearance' => context.tr(appearanceLabel(preferences.appearance)),
        'language' =>
          languageNames[preferences.locale] ?? context.tr('System language'),
        'gestures' => context.tr(
          gesturePresetLabel(preferences.gestures.preset),
        ),
        _ => null,
      };
      return Scaffold(
        appBar: const InkScreenHeader(title: LText('Settings')),
        body: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SettingsSearchField(
                onChanged: (text) {
                  final query = text.toLowerCase().trim();
                  if (query != _query) setState(() => _query = query);
                },
              ),
              const SizedBox(height: 4),
              ...settingsMenu(
                context,
                query: _query,
                entry: (entry, path) => InkSettingsRow(
                  key: ValueKey('settings-entry-${entry.id}'),
                  icon: entry.icon,
                  title: context.tr(entry.title),
                  subtitle: path ?? entry.description,
                  value: value(entry),
                  onTap: () => context.push('/settings/${entry.id}'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (section == 'reading') {
      return const LibraryDefaultsScreen(includeGlobal: true);
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
                    showReset: !widget.embedded,
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
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
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
              const SizedBox(height: 12),
              InkPanel(
                framed: false,
                // The page header already names the page; setup steps keep
                // their own heading.
                title: widget.embedded && !wide ? 'Appearance' : null,
                icon: InkIcons.palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LText('Application theme'),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    InkSlider(
                      sliderKey: const Key('panel-opacity'),
                      label: context.tr('Panel opacity'),
                      value: preferences.panelOpacity,
                      min: UiPreferences.minPanelOpacity,
                      max: UiPreferences.maxPanelOpacity,
                      divisions: 6,
                      enabled: !_saving && data.hasValue,
                      formatValue: (value) =>
                          context.tr('{0} %', [(value * 100).round()]),
                      onCommitted: (value) => _save(
                        (current) => current.copyWith(panelOpacity: value),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const LText('Catalogue density'),
                    const SizedBox(height: 8),
                    SegmentedButton<CatalogueDensity>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: CatalogueDensity.comfortable,
                          label: LText('Comfortable'),
                        ),
                        ButtonSegment(
                          value: CatalogueDensity.compact,
                          label: LText('Compact'),
                        ),
                      ],
                      selected: {preferences.density},
                      onSelectionChanged: _saving
                          ? null
                          : (values) => _save(
                              (current) =>
                                  current.copyWith(density: values.single),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const LText(
                      'Reader backgrounds are configured separately in Reading.',
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
              InkPanel(
                framed: false,
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
