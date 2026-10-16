import '../../../app/widgets/ink_slider.dart';
import 'about_content.dart';
import 'preference_labels.dart';
import '../../../app/l10n/app_strings.dart';
import 'language_settings.dart';
import 'settings_sections.dart';
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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.section,
    this.embedded = false,
    this.onSaved,
  });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('Unable to save appearance settings. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(uiPreferencesProvider);
    final preferences = data.asData?.value ?? const UiPreferences();
    final section = widget.section;
    if (section == null) {
      return InkContent(
        maxWidth: InkoraLayout.maxSettingsWidth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LText('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(InkIcons.magnifyingGlass),
                hintText: context.tr("Search settings"),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase().trim()),
            ),
            const SizedBox(height: 12),
            for (final entry in settingsSections.where(
              (entry) => '${context.tr(entry.$2)} ${context.tr(entry.$3)}'
                  .toLowerCase()
                  .contains(_query),
            ))
              InkSettingsRow(
                icon: entry.$4,
                title: context.tr(entry.$2),
                subtitle: entry.$1 == 'appearance'
                    ? '${context.tr(appearanceLabel(preferences.appearance))} · ${context.tr(densityLabel(preferences.density))}'
                    : entry.$3,
                onTap: () => context.push('/settings/${entry.$1}'),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/setup?edit=true'),
              child: const LText('Guided setup'),
            ),
          ],
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
        appBar: widget.embedded
            ? null
            : AppBar(
                title: LText(section == 'quality' ? 'Quality' : 'Reading'),
              ),
        body: InkContent(
          maxWidth: InkoraLayout.maxSettingsWidth,
          child: FutureBuilder(
            future: ref.watch(databaseProvider),
            builder: (context, snapshot) => snapshot.hasError
                ? const Center(
                    child: LText('Unable to open reading preferences.'),
                  )
                : !snapshot.hasData || account == null
                ? const Center(child: CircularProgressIndicator())
                : ReaderSettingsSheet(
                    key: ValueKey(account),
                    store: ReaderStore(snapshot.requireData, account),
                    qualityOnly: section == 'quality',
                    onSaved: widget.onSaved,
                  ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: LText(switch (section) {
                'language' => 'Language',
                'gestures' => 'Reading gestures',
                'appearance' => 'Appearance',
                'downloads' => 'Download settings',
                'accessibility' => 'Accessibility',
                _ => 'About Inkora',
              }),
            ),
      body: InkContent(
        maxWidth: InkoraLayout.maxSettingsWidth,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                title: context.tr("Appearance"),
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
                    ),
                    if (section == 'appearance') ...[
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
                    ] else
                      TextButton(
                        onPressed: () => context.push('/settings/appearance'),
                        child: const LText('More appearance settings'),
                      ),
                  ],
                ),
              ),
            ],
            if (section == 'gestures') const GestureSettings(),
            if (section == 'language') const LanguageSettings(),
            if (section == 'downloads') const DownloadSettingsPanel(),
            if (section == 'accessibility')
              InkPanel(
                title: context.tr("Reading comfort"),
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
