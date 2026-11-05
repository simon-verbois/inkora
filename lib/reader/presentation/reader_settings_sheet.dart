import '../../app/widgets/ink_settings_section.dart';
import 'reader_settings_scope_selector.dart';
import '../../app/icons/inkora_icons.dart';
import 'ebook_style_picker.dart';
import 'ebook_colors_dialog.dart';
import 'ebook_background_picker.dart';
import 'ebook_settings_controls.dart';
import 'ebook_presentation.dart';
import 'reader_settings_layout.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/widgets/inkora_widgets.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/reader_store.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';
import '../domain/webtoon_layout.dart';

/// Scoped reading preferences. Every change applies immediately: it is
/// persisted to the selected scope (latest value wins, unchanged values are
/// skipped) and the open reader follows the account's settings stream. There
/// is no Save or Cancel; controls are grouped in one scrolling form.
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    required this.store,
    this.manifest,
    this.libraryId,
    this.onSaved,
    this.showTitle = true,
    this.showScope = true,
    this.showLibraryApply = true,
    this.qualityOnly = false,
    this.upscalingControls,
    this.modal = false,
    super.key,
  });

  /// Called by [ReaderSettingsSheetState.savePreferences] and after the
  /// library-wide replacement; the editor pops its route when absent.
  final VoidCallback? onSaved;
  final bool showTitle;
  final bool showScope;
  final bool showLibraryApply;

  final bool qualityOnly;
  final Widget? upscalingControls;
  final bool modal;
  final ReaderStore store;
  final ReaderManifest? manifest;
  final String? libraryId;
  @override
  ReaderSettingsSheetState createState() => ReaderSettingsSheetState();
}

typedef _Target = (SettingsScope, String);

class ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late SettingsScope _scope;
  Map<SettingsScope, ReadingOverrides> _layers = {};
  ReadingOverrides _overrides = const ReadingOverrides();
  bool _loading = true;
  late final double _maximumStripRatio;
  int _generation = 0;
  String? _message;

  // Live persistence: one writer, latest value per change, no duplicate rows.
  final _persisted = <_Target, String>{};
  (_Target, ReadingOverrides)? _queued;
  Future<void>? _writer;
  bool _writeFailed = false;

  bool get _supportsTypography =>
      _effective.mode == ReadingMode.ebook &&
      (widget.manifest == null ||
          widget.manifest!.documentType == 'application/epub+zip');
  bool get _rasterControls =>
      widget.manifest?.isDocument == false ||
      _effective.mode != ReadingMode.ebook;
  String _id(SettingsScope scope) => switch (scope) {
    SettingsScope.global => '',
    SettingsScope.library => widget.libraryId ?? widget.manifest!.libraryId!,
    SettingsScope.series => widget.manifest!.seriesId!,
    SettingsScope.book => widget.manifest!.bookId,
  };
  @override
  void initState() {
    super.initState();
    // A library/global editor has no book geometry: show the conservative
    // long-strip bound. Book sheets scan their immutable manifest only once.
    _maximumStripRatio =
        widget.manifest?.pages.fold<double>(
          0,
          (maximum, page) => math.max(maximum, 1 / page.aspectRatio),
        ) ??
        double.infinity;
    _scope = widget.libraryId != null
        ? SettingsScope.library
        : widget.manifest == null
        ? SettingsScope.global
        : SettingsScope.book;
    _load(_scope);
  }

  Future<void> _load(SettingsScope scope) async {
    final generation = ++_generation;
    setState(() {
      _scope = scope;
      _loading = true;
      _message = null;
    });
    try {
      // Read layers only after earlier live writes reached the store.
      await _flush();
      final layers = await widget.store.preferenceLayers(
        libraryId: widget.libraryId ?? widget.manifest?.libraryId,
        seriesId: widget.manifest?.seriesId,
        bookId: widget.manifest?.bookId,
      );
      final ebookConfigured = layers.values.any(
        (layer) => layer.mode == ReadingMode.ebook,
      );
      final stored = layers[scope];
      final value =
          stored ??
          (widget.manifest?.isDocument == true
              ? ReadingOverrides(
                  mode: ReadingMode.ebook,
                  background: ebookConfigured ? null : ReadingBackground.sepia,
                )
              : const ReadingOverrides());
      if (mounted && generation == _generation) {
        if (stored != null) {
          _persisted[(scope, _id(scope))] = jsonEncode(stored.toJson());
        }
        setState(() {
          _layers = layers;
          _overrides = value;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _message = 'Unable to load reading preferences.';
        });
      }
    }
  }

  /// Applies [next] to the selected scope at once and persists it.
  void _apply(ReadingOverrides next) {
    setState(() {
      _overrides = next;
      _message = null;
    });
    _queued = ((_scope, _id(_scope)), next);
    _writer ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_queued != null) {
        final (target, value) = _queued!;
        _queued = null;
        final encoded = jsonEncode(value.toJson());
        if (_persisted[target] == encoded) continue;
        await widget.store.saveOverrides(target.$1, target.$2, value);
        _persisted[target] = encoded;
        _writeFailed = false;
      }
    } catch (_) {
      _queued = null;
      _writeFailed = true;
      if (mounted) {
        setState(() => _message = 'Unable to save reading preferences.');
      }
    } finally {
      _writer = null;
    }
  }

  Future<void> _flush() async {
    while (_writer != null) {
      await _writer;
    }
  }

  void _change(String key, Object? value) {
    final values = {..._overrides.toJson(), key: value};
    if (key == 'layout') values['spreads'] = null;
    if (key == 'spreadPairing') values['spreadOffset'] = null;
    if (key == 'mode' && value != _overrides.mode?.name) {
      if (value == 'ebook') values['background'] = 'sepia';
      for (final field in [
        'direction',
        'fit',
        'spacing',
        'spreads',
        'layout',
        'spreadOffset',
        'spreadPairing',
      ]) {
        values[field] = null;
      }
    }
    _apply(ReadingOverrides.fromJson(values));
  }

  ReadingSettings get _effective => ReadingSettings.resolveScopes({
    for (final scope in SettingsScope.values)
      if (scope.index < _scope.index && _layers[scope] != null)
        scope: _layers[scope]!,
    _scope: widget.manifest?.isDocument == true
        ? ReadingOverrides.fromJson({..._overrides.toJson(), 'mode': 'ebook'})
        : _overrides,
  });

  Widget _select(String label, String key, Map<String, String> choices) {
    final settings = _effective;
    final raw = switch (key) {
      'mode' => settings.mode.name,
      'direction' => settings.direction.name,
      'fit' => settings.fit.name,
      'layout' => settings.layout.name,
      'spreadPairing' => settings.spreadPairing.name,
      _ => throw ArgumentError('Unknown reading setting'),
    };
    return ReaderChoiceGroup(
      id: key,
      label: label,
      choices: choices,
      selected: raw,
      onSelected: _loading ? null : (value) => _change(key, value),
    );
  }

  Widget _imageQuality() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ReaderSettingsGrid(
        children: [
          _qualityChoice<ImageSampling>(
            'Image scaling',
            ImageSampling.values,
            _effective.imageQuality[RasterFormat.jpeg]?.sampling ??
                ImageSampling.high,
            (value) => switch (value) {
              ImageSampling.nearest => 'Nearest neighbour',
              ImageSampling.smooth => 'Bilinear',
              ImageSampling.high => 'High quality',
            },
            (value) => RasterQuality(
              sampling: value,
              filter:
                  _effective.imageQuality[RasterFormat.jpeg]?.filter ??
                  VisualFilter.original,
            ),
          ),
          _qualityChoice<VisualFilter>(
            'Visual filter',
            VisualFilter.values,
            _effective.imageQuality[RasterFormat.jpeg]?.filter ??
                VisualFilter.original,
            (value) => switch (value) {
              VisualFilter.original => 'Original colours',
              VisualFilter.grayscale => 'Grayscale',
              VisualFilter.sepia => 'Sepia',
              VisualFilter.inverted => 'Invert colours',
            },
            (value) => RasterQuality(
              filter: value,
              sampling:
                  _effective.imageQuality[RasterFormat.jpeg]?.sampling ??
                  ImageSampling.high,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const LText(
        'High quality uses the rendering engine’s best image sampling. Scaling cannot restore details missing from the source.',
      ),
    ],
  );

  Widget _qualityChoice<T extends Enum>(
    String label,
    List<T> values,
    T current,
    String Function(T) text,
    RasterQuality Function(T) update,
  ) => ReaderChoiceGroup(
    id: 'quality-all-${label == 'Image scaling' ? 'sampling' : 'filter'}',
    label: label,
    choices: {for (final value in values) value.name: text(value)},
    selected: current.name,
    onSelected: _loading
        ? null
        : (name) {
            final value = values.firstWhere((v) => v.name == name);
            _change('imageQuality', {
              for (final format in RasterFormat.values)
                format.name: update(value).toJson(),
            });
          },
  );

  Widget _webtoonQuality(BuildContext context) {
    final settings = _effective;
    final quality = settings.webtoonQuality;
    final custom = settings.customWebtoon;
    final profile = settings.webtoonProfile;
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final width = WebtoonLayout.readingWidth(
      size.width,
      size.height,
      fullWidth: settings.fit == ReadingFit.width,
    );
    final budget = WebtoonBudget.resolve(
      profile,
      physicalWidth: width * ratio,
      physicalHeight: size.height * ratio,
      maximumStripScreens: width * _maximumStripRatio / size.height,
    );
    final theme = Theme.of(context);
    Widget slider({
      required String key,
      required String label,
      required String value,
      required double current,
      required double min,
      required double max,
      required int divisions,
      required ValueChanged<double> onChanged,
    }) => InkSlider(
      sliderKey: Key('webtoon-$key'),
      label: label,
      value: current.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      enabled: !_loading,
      formatValue: (v) => switch (key) {
        'sharpness' => context.tr('{0} %', [(v * 100).round()]),
        'preload' => AppStrings.of(context).quantity(v.round(), 'screen'),
        _ => context.tr('{0} MiB', [v.round()]),
      },
      onCommitted: onChanged,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ReaderChoiceGroup(
          id: 'webtoon-quality',
          label: 'Webtoon image quality',
          choices: const {
            'saver': 'Saver',
            'balanced': 'Balanced',
            'sharp': 'Sharp',
            'custom': 'Custom',
          },
          selected: quality.name,
          onSelected: _loading
              ? null
              : (value) => _change('webtoonQuality', value),
        ),
        const SizedBox(height: 6),
        LText(switch (quality) {
          WebtoonQuality.saver =>
            'Lightest on memory and data · softer images, less preloading.',
          WebtoonQuality.balanced =>
            'Recommended · sharp strips with smooth scrolling.',
          WebtoonQuality.sharp => 'Full screen resolution · uses more memory.',
          WebtoonQuality.custom => 'Adjust each control to your device.',
        }, style: theme.textTheme.bodySmall),
        if (quality == WebtoonQuality.custom) ...[
          const SizedBox(height: 8),
          slider(
            key: 'sharpness',
            label: context.tr("Sharpness"),
            value: context.tr('{0} %', [(custom.sharpness * 100).round()]),
            current: custom.sharpness,
            min: WebtoonQualityProfile.minSharpness,
            max: WebtoonQualityProfile.maxSharpness,
            divisions: 10,
            onChanged: (v) =>
                _change('webtoonSharpness', (v * 20).round() / 20),
          ),
          slider(
            key: 'preload',
            label: context.tr("Preload ahead"),
            value: AppStrings.of(context)
                .quantity(custom.preloadScreens, 'screen'),
            current: custom.preloadScreens.toDouble(),
            min: WebtoonQualityProfile.minPreload.toDouble(),
            max: WebtoonQualityProfile.maxPreload.toDouble(),
            divisions:
                WebtoonQualityProfile.maxPreload -
                WebtoonQualityProfile.minPreload,
            onChanged: (v) => _change('webtoonPreload', v.round()),
          ),
          slider(
            key: 'memory',
            label: context.tr("Image memory"),
            value: context.tr('{0} MiB', [custom.memoryMiB]),
            current: custom.memoryMiB.toDouble(),
            min: WebtoonQualityProfile.minMemoryMiB.toDouble(),
            max: WebtoonQualityProfile.maxMemoryMiB.toDouble(),
            divisions:
                (WebtoonQualityProfile.maxMemoryMiB -
                    WebtoonQualityProfile.minMemoryMiB) ~/
                16,
            onChanged: (v) =>
                _change('webtoonMemoryMiB', (v / 16).round() * 16),
          ),
        ],
        LText(
          budget.preloadScreens < profile.preloadScreens ||
                  budget.sharpness < profile.sharpness
              ? 'On this screen: {0} % sharpness · preload: {1} · up to {2} MiB (limited by memory)'
              : 'On this screen: {0} % sharpness · preload: {1} · up to {2} MiB',
          arguments: [
            (budget.sharpness * 100).round(),
            AppStrings.of(context).quantity(budget.preloadScreens, 'screen'),
            profile.memoryMiB,
          ],
          key: const Key('webtoon-quality-estimate'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Waits until every live change reached the store, then notifies the
  /// owner (setup Next, library return) or closes the editor.
  Future<bool> savePreferences() async {
    if (_loading) return false;
    await _flush();
    if (!mounted || _writeFailed) return false;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.of(context).pop();
    }
    return true;
  }

  bool _libraryConfirmationOpen = false;

  Future<void> _applyToLibrary() async {
    if (_loading || _libraryConfirmationOpen) return;
    setState(() => _libraryConfirmationOpen = true);
    final bool? confirmed;
    try {
      confirmed = await showInkPopup<bool>(
        context: context,
        heightFactor: .45,
        child: Builder(
          builder: (sheetContext) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InkSheetHeader(title: 'Apply to all series and books?'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LText(
                        'Apply these preferences to every series and book in this library, replacing their custom reading preferences.',
                      ),
                      const SizedBox(height: 24),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 12,
                        overflowSpacing: 12,
                        children: [
                          OutlinedButton(
                            key: const Key('library-apply-cancel'),
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: const LText('Cancel'),
                          ),
                          FilledButton(
                            key: const Key('library-apply-confirm'),
                            onPressed: () => Navigator.pop(sheetContext, true),
                            child: const LText('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _libraryConfirmationOpen = false);
    }
    if (confirmed != true || !mounted) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await _flush();
      await widget.store.applyLibraryDefaults(
        _id(SettingsScope.library),
        _overrides,
      );
      _persisted[(SettingsScope.library, _id(SettingsScope.library))] =
          jsonEncode(_overrides.toJson());
      if (mounted) {
        setState(() => _loading = false);
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Unable to apply library preferences. Try again.';
        });
      }
    }
  }

  Map<SettingsScope, String> get _scopeChoices => {
    if (widget.manifest != null) SettingsScope.book: 'This book',
    if (widget.manifest?.seriesId != null) SettingsScope.series: 'Series',
    if (widget.libraryId != null || widget.manifest?.libraryId != null)
      SettingsScope.library: 'Library',
    SettingsScope.global: 'Global',
  };

  Widget _backgroundControls({required bool ebook}) => ReaderBackgroundSwatches(
    choices: {
      ReadingBackground.white: 'White',
      ReadingBackground.sepia: 'Sepia',
      if (ebook) ...{
        ReadingBackground.gray: 'Gray',
        ReadingBackground.slate: 'Night',
      },
      ReadingBackground.black: 'Black',
    },
    selected: ebook && _effective.ebook.customColors
        ? null
        : _effective.background.current,
    onCustom: ebook && _supportsTypography && !_loading ? _customColors : null,
    customSelected: _effective.ebook.customColors,
    onSelected: _loading
        ? null
        : (value) {
            // Freeze the legacy Paper fallback before changing its base color.
            _apply(
              ReadingOverrides.fromJson({
                ..._overrides.toJson(),
                'background': value.name,
                if (ebook)
                  'ebook': {
                    ...?_overrides.ebook,
                    'paperTexture': _effective.paperTexture,
                    'customColors': false,
                  },
              }),
            );
          },
  );

  Future<void> _customColors() async {
    final scope = _scope;
    final result = await showDialog<({int background, int? text})>(
      context: context,
      builder: (_) => EbookColorsDialog(settings: _effective.ebook),
    );
    if (result == null || !mounted || _scope != scope) return;
    _change('ebook', {
      ...?_overrides.ebook,
      'customColors': true,
      'backgroundColor': result.background,
      'textColor': result.text,
    });
  }

  Widget _ebookControls(EbookControlsSection section) => EbookSettingsControls(
    section: section,
    settings: _effective.ebook,
    onChanged: (key, value) =>
        _change('ebook', {...?_overrides.ebook, key: value}),
  );

  Widget _appearanceControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      EbookSettingsControls(
        section: EbookControlsSection.typography,
        settings: _effective.ebook,
        backgroundPicker: EbookBackgroundPicker(
          settings: _effective,
          onSelected: _loading
              ? null
              : (background) => _apply(
                  ReadingOverrides.fromJson({
                    ..._overrides.toJson(),
                    'background': background.name,
                    'ebook': {
                      ...?_overrides.ebook,
                      'customColors': false,
                      'paperTexture': _effective.paperTexture,
                    },
                  }),
                ),
          onCustom: _loading ? null : _customColors,
        ),
        onChanged: (key, value) =>
            _change('ebook', {...?_overrides.ebook, key: value}),
      ),
      if (EbookPresentation.supported)
        SwitchListTile.adaptive(
          key: const Key('ebook-paper-texture'),
          contentPadding: EdgeInsets.zero,
          title: const LText('Paper texture'),
          value: _effective.paperTexture,
          onChanged: _loading
              ? null
              : (value) => _change('ebook', {
                  ...?_overrides.ebook,
                  'paperTexture': value,
                }),
        ),
    ],
  );

  Widget _animationControl() => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: const LText('Page turn animation'),
    value: _effective.pageAnimation,
    onChanged: _loading ? null : (value) => _change('pageAnimation', value),
  );

  Widget _navigationControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ebookControls(EbookControlsSection.navigation),
      if (!_effective.ebook.scroll && EbookPresentation.supported)
        _animationControl(),
    ],
  );

  Widget _layoutControls() {
    // A global ebook default must not expose typography for a raster volume.
    final mode = _effective.mode == ReadingMode.ebook && _rasterControls
        ? ReadingMode.comics
        : _effective.mode;
    final fit = _effective.fit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading('Page layout'),
        if (mode != ReadingMode.ebook && mode != ReadingMode.webtoon) ...[
          _select('Direction', 'direction', {
            'leftToRight': 'Left to right',
            'rightToLeft': 'Right to left',
            'vertical': 'Vertical pages',
          }),
          const SizedBox(height: 20),
        ],
        if (mode != ReadingMode.ebook ||
            widget.manifest?.documentType == 'application/pdf') ...[
          _select(
            'Fit',
            'fit',
            mode == ReadingMode.webtoon
                ? {
                    'comfort': 'Comfortable width',
                    'width': 'Full width',
                    if (fit == ReadingFit.page)
                      'page': 'Comfortable width (legacy)',
                  }
                : {
                    'page': 'Fit page',
                    'width': 'Fit width',
                    if (mode != ReadingMode.ebook) 'content': 'Fit content',
                  },
          ),
          const SizedBox(height: 20),
        ],
        if (mode != ReadingMode.ebook && mode != ReadingMode.webtoon) ...[
          _select('Page layout', 'layout', {
            'single': 'Single page',
            'doublePage': 'Two pages',
            'automatic': 'Automatic',
          }),
          if (_effective.layout == ReadingLayout.automatic) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: LText(
                'Two pages in landscape windows and on tablets.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _select('Pages', 'spreadPairing', {
            SpreadPairing.automatic.name: 'Automatic',
            SpreadPairing.unshifted.name: 'Pair pages from the first page',
            SpreadPairing.shifted.name: 'Shift page pairing by one',
          }),
          const SizedBox(height: 20),
        ],
        _sectionHeading('Appearance'),
        _backgroundControls(ebook: mode == ReadingMode.ebook),
        const SizedBox(height: 20),
        if (mode != ReadingMode.ebook)
          InkSlider(
            sliderKey: const Key('reader-spacing'),
            label: context.tr('Page spacing'),
            value: _effective.spacing.clamp(0, 64),
            min: 0,
            max: 64,
            divisions: 16,
            enabled: !_loading,
            formatValue: (v) => context.tr('{0} px', [v.round()]),
            onCommitted: (v) => _change('spacing', v.roundToDouble()),
          ),
        if (mode == ReadingMode.ebook) ...[
          EbookSettingsControls(
            section: EbookControlsSection.all,
            settings: _effective.ebook,
            pdf: widget.manifest?.documentType == 'application/pdf',
            onChanged: (key, value) =>
                _change('ebook', {...?_overrides.ebook, key: value}),
          ),
        ],
        if (mode != ReadingMode.webtoon &&
            (mode != ReadingMode.ebook || !_effective.ebook.scroll) &&
            (widget.manifest?.documentType != 'application/epub+zip' ||
                EbookPresentation.supported)) ...[
          _sectionHeading('Navigation'),
          _animationControl(),
        ],
      ],
    );
  }

  Widget _sectionHeading(String title, {bool first = false}) =>
      InkSettingsHeading(title: title, first: first);

  Widget _sectionedContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.qualityOnly) ...[
        if (widget.manifest?.isDocument != true) ...[
          _sectionHeading('Reading mode', first: true),
          DropdownButtonFormField<ReadingMode>(
            key: const Key('reader-mode-selector'),
            initialValue: _effective.mode,
            decoration: InputDecoration(labelText: context.tr('Mode')),
            icon: const Icon(InkIcons.caretDown, size: 20),
            isExpanded: true,
            itemHeight: null,
            items: [
              for (final entry in {
                ReadingMode.manga: 'Manga',
                ReadingMode.comics: 'Comics',
                ReadingMode.webtoon: 'Webtoon',
                if (widget.manifest == null ||
                    _effective.mode == ReadingMode.ebook)
                  ReadingMode.ebook: 'Ebooks',
              }.entries)
                DropdownMenuItem(
                  key: ValueKey('reader-mode-option-${entry.key.name}'),
                  value: entry.key,
                  child: LText(entry.value),
                ),
            ],
            onChanged: _loading
                ? null
                : (mode) {
                    if (mode != null && mode != _effective.mode) {
                      _change('mode', mode.name);
                    }
                  },
          ),
        ],
        if (_supportsTypography) ...[
          _sectionHeading(
            'Appearance',
            first: widget.manifest?.isDocument == true,
          ),
          _appearanceControls(),
          _sectionHeading('Page layout'),
          _ebookControls(EbookControlsSection.layout),
          _sectionHeading('Navigation'),
          _navigationControls(),
          _sectionHeading('Templates'),
          EbookStylePicker(
            settings: _effective,
            onSelected: (style) => _apply(style.apply(_overrides)),
          ),
        ] else
          _layoutControls(),
      ],
      if (widget.qualityOnly || widget.manifest?.isDocument == false) ...[
        _sectionHeading('Rendering', first: widget.qualityOnly),
        _imageQuality(),
        if (widget.upscalingControls != null) ...[widget.upscalingControls!],
        if (widget.qualityOnly || _effective.mode == ReadingMode.webtoon) ...[
          _sectionHeading('Preloading'),
          _webtoonQuality(context),
        ],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: !widget.modal,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.modal && widget.showTitle)
              InkSheetHeader(
                title: widget.qualityOnly
                    ? 'Image quality'
                    : 'Reading preferences',
              ),
            if (widget.showScope && !widget.qualityOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: ReaderSettingsScopeSelector(
                  scope: _scope,
                  choices: widget.manifest != null && widget.libraryId == null
                      ? _scopeChoices
                      : {_scope: _scopeChoices[_scope]!},
                  onSelected:
                      widget.manifest != null &&
                          widget.libraryId == null &&
                          !_loading
                      ? (value) => _load(value)
                      : null,
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            Flexible(
              child: SingleChildScrollView(
                key: PageStorageKey(('reader-settings', _scope)),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AbsorbPointer(
                      absorbing: _loading,
                      child: _sectionedContent(),
                    ),
                    if (_scope == SettingsScope.library &&
                        widget.showLibraryApply) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        key: const Key('apply-library-defaults'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _loading || _libraryConfirmationOpen
                            ? null
                            : _applyToLibrary,
                        icon: const Icon(InkIcons.books),
                        label: const LText('Apply to all'),
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      LText(
                        _message!,
                        key: const Key('reader-settings-message'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
