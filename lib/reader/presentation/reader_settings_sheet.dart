import 'reader_settings_scope_selector.dart';
import '../../app/icons/inkora_icons.dart';
import 'ebook_style_picker.dart';
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

enum _PreferenceTab {
  appearance,
  layout,
  navigation,
  style,
  rendering,
  preloading,
}

/// Scoped reading preferences. Every change applies immediately: it is
/// persisted to the selected scope (latest value wins, unchanged values are
/// skipped) and the open reader follows the account's settings stream. There
/// is no Save or Cancel; the header menu provides confirmed tab resets.
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    required this.store,
    this.manifest,
    this.libraryId,
    this.onSaved,
    this.showReset = true,
    this.qualityOnly = false,
    this.upscalingControls,
    this.onResetRendering,
    this.modal = false,
    super.key,
  });

  /// Called by [ReaderSettingsSheetState.savePreferences] and after the
  /// library-wide replacement; the editor pops its route when absent.
  final VoidCallback? onSaved;
  final bool showReset;
  final bool qualityOnly;
  final Widget? upscalingControls;
  final Future<void> Function()? onResetRendering;
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
  _PreferenceTab? _tab;

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
  List<_PreferenceTab> get _tabs => widget.qualityOnly
      ? [_PreferenceTab.rendering, _PreferenceTab.preloading]
      : [
          if (_supportsTypography) ...[
            _PreferenceTab.appearance,
            _PreferenceTab.layout,
            _PreferenceTab.navigation,
            _PreferenceTab.style,
          ] else
            _PreferenceTab.layout,
          if (widget.manifest != null && !widget.manifest!.isDocument)
            _PreferenceTab.rendering,
          if (widget.manifest != null && _effective.mode == ReadingMode.webtoon)
            _PreferenceTab.preloading,
        ];
  _PreferenceTab get _activeTab => _tabs.contains(_tab) ? _tab! : _tabs.first;
  bool get _showQuality =>
      _activeTab == _PreferenceTab.rendering ||
      _activeTab == _PreferenceTab.preloading;
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
      wrapLabels: key == 'spreadPairing',
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
        LText('Webtoon image quality', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (value, label) in const [
              (WebtoonQuality.saver, 'Saver'),
              (WebtoonQuality.balanced, 'Balanced'),
              (WebtoonQuality.sharp, 'Sharp'),
              (WebtoonQuality.custom, 'Custom'),
            ])
              ChoiceChip(
                key: Key('webtoon-quality-${value.name}'),
                label: LText(label),
                selected: quality == value,
                onSelected: _loading
                    ? null
                    : (_) => _change('webtoonQuality', value.name),
              ),
          ],
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

  Future<void> _applyToLibrary() async {
    final confirmed = await confirmInk(
      context,
      title: 'Apply to all series and books?',
      message: 'Apply these preferences to every series and book in this library, replacing their custom reading preferences.',
      confirmLabel: 'Apply to all series and books',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
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

  Future<void> _reset() async {
    final targetScope = _scope;
    final targetTab = _activeTab;
    final confirmed = await confirmInk(
      context,
      title: 'Reset to default?',
      message:
          'The custom settings of this tab are removed for the selected scope.',
      confirmLabel: 'Reset to default',
      destructive: true,
    );
    if (!confirmed ||
        !mounted ||
        _scope != targetScope ||
        _activeTab != targetTab) {
      return;
    }
    final values = {..._overrides.toJson()};
    if (_supportsTypography && !_showQuality) {
      final ebook = {...?_overrides.ebook};
      final fields = switch (targetTab) {
        _PreferenceTab.appearance => [
          'font',
          'fontSize',
          'lineHeight',
          'justify',
          'publisherStyles',
        ],
        _PreferenceTab.layout => [
          'margins',
          'pageInsets',
          'columns',
          'columnSeparator',
        ],
        _PreferenceTab.navigation => ['scroll', 'tapToTurnPages'],
        _PreferenceTab.style => [
          'font',
          'fontSize',
          'lineHeight',
          'margins',
          'justify',
          'publisherStyles',
        ],
        _ => <String>[],
      };
      for (final field in fields) {
        ebook.remove(field);
      }
      if (targetTab == _PreferenceTab.appearance ||
          targetTab == _PreferenceTab.style) {
        values.remove('background');
      }
      if (targetTab == _PreferenceTab.navigation) {
        values.remove('pageAnimation');
      }
      values['ebook'] = ebook.isEmpty ? null : ebook;
      _apply(ReadingOverrides.fromJson(values));
      return;
    }
    if (_activeTab == _PreferenceTab.rendering &&
        widget.onResetRendering != null) {
      try {
        await widget.onResetRendering!();
      } catch (_) {
        if (mounted) notifyInk(context, 'Unable to reset settings. Try again.');
        return;
      }
      if (!mounted || _scope != targetScope || _activeTab != targetTab) return;
    }
    for (final field
        in _activeTab == _PreferenceTab.rendering
            ? ['imageQuality']
            : _activeTab == _PreferenceTab.preloading
            ? [
                'webtoonQuality',
                'webtoonSharpness',
                'webtoonPreload',
                'webtoonMemoryMiB',
              ]
            : [
                'mode',
                'direction',
                'fit',
                'background',
                'spacing',
                'spreads',
                'layout',
                'spreadOffset',
                'spreadPairing',
                'pageAnimation',
                'ebook',
              ]) {
      values[field] = null;
    }
    if (!_showQuality) {
      values['libraryDefaults'] =
          _scope == SettingsScope.book && widget.manifest?.libraryId != null;
    }
    _apply(ReadingOverrides.fromJson(values));
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
      if (ebook &&
          EbookPresentation.supported &&
          widget.manifest?.documentType != 'application/pdf')
        ReadingBackground.paper: 'Paper',
      ReadingBackground.sepia: 'Sepia',
      if (ebook) ...{
        ReadingBackground.gray: 'Gray',
        ReadingBackground.slate: 'Night',
      },
      ReadingBackground.black: 'Black',
    },
    selected: _effective.background.current,
    onSelected: _loading ? null : (value) => _change('background', value.name),
  );

  Widget _ebookControls(EbookControlsSection section) => EbookSettingsControls(
    section: section,
    settings: _effective.ebook,
    onChanged: (key, value) =>
        _change('ebook', {...?_overrides.ebook, key: value}),
  );

  Widget _appearanceControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.manifest == null) ...[
        _select('Mode', 'mode', {
          'manga': 'Manga',
          'comics': 'Comics',
          'webtoon': 'Webtoon',
          'ebook': 'Ebooks',
        }),
        const SizedBox(height: 20),
      ],
      _backgroundControls(ebook: true),
      const SizedBox(height: 20),
      _ebookControls(EbookControlsSection.typography),
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
        if (widget.manifest?.isDocument != true) ...[
          _select('Mode', 'mode', {
            'manga': 'Manga',
            'comics': 'Comics',
            'webtoon': 'Webtoon',
            if (widget.manifest == null || _effective.mode == ReadingMode.ebook)
              'ebook': 'Ebooks',
          }),
          const SizedBox(height: 20),
        ],
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
            const SizedBox(height: 4),
            LText(
              'Two pages in landscape windows and on tablets.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          _select('Pages', 'spreadPairing', {
            SpreadPairing.automatic.name: 'Automatic',
            SpreadPairing.unshifted.name: 'Pair pages from the first page',
            SpreadPairing.shifted.name: 'Shift page pairing by one',
          }),
          const SizedBox(height: 20),
        ],
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
                EbookPresentation.supported))
          _animationControl(),
      ],
    );
  }

  Widget _tabContent() => switch (_activeTab) {
    _PreferenceTab.appearance => _appearanceControls(),
    _PreferenceTab.layout =>
      _supportsTypography
          ? _ebookControls(EbookControlsSection.layout)
          : _layoutControls(),
    _PreferenceTab.navigation => _navigationControls(),
    _PreferenceTab.style => EbookStylePicker(
      settings: _effective,
      onSelected: (style) => _apply(style.apply(_overrides)),
    ),
    _PreferenceTab.rendering => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _imageQuality(),
        if (widget.upscalingControls != null) ...[
          const SizedBox(height: 24),
          widget.upscalingControls!,
        ],
      ],
    ),
    _PreferenceTab.preloading => _webtoonQuality(context),
  };

  @override
  Widget build(BuildContext context) => SafeArea(
    top: !widget.modal,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final tabs = _tabs;
        final preferredHeight = widget.modal
            ? math.min(
                available,
                math.min(MediaQuery.sizeOf(context).height * .86, 560 * scale),
              )
            : available;
        final height = widget.modal && tabs.length == 1
            ? math.min(preferredHeight, 420 * scale)
            : preferredHeight;
        // Large type can make the header taller than a phone sheet. Let the
        // header and body scroll then, keeping the scope footer pinned.
        final short = scale > 1.3 || height < (widget.modal ? 420 : 180);
        final reset = widget.showReset
            ? PopupMenuButton<String>(
                key: const Key('reader-settings-menu'),
                tooltip: context.tr('More'),
                enabled: !_loading,
                useRootNavigator: true,
                icon: const Icon(InkIcons.dotsThree),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset',
                    key: Key('reader-settings-reset'),
                    child: LText('Reset this tab'),
                  ),
                ],
                onSelected: (_) => _reset(),
              )
            : null;
        final scope = widget.manifest != null && widget.libraryId == null;
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.qualityOnly)
              Flexible(
                child: ReaderSettingsScopeSelector(
                  scope: _scope,
                  choices: scope
                      ? _scopeChoices
                      : {_scope: _scopeChoices[_scope]!},
                  onSelected: scope && !_loading
                      ? (value) => _load(value)
                      : null,
                ),
              ),
            ?reset,
          ],
        );
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.modal)
              LayoutBuilder(
                builder: (context, bounds) {
                  final title = widget.qualityOnly
                      ? 'Image quality'
                      : 'Reading preferences';
                  if (bounds.maxWidth / scale < 420) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkSheetHeader(title: title),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: actions,
                          ),
                        ),
                      ],
                    );
                  }
                  return InkSheetHeader(title: title, action: actions);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
          ],
        );
        final navigation = tabs.length < 2
            ? const SizedBox.shrink()
            : TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                tabs: [
                  for (final tab in tabs)
                    Tab(
                      height: math.max(
                        48,
                        MediaQuery.textScalerOf(context).scale(14 * 1.6) + 16,
                      ),
                      text: context.tr(switch (tab) {
                        _PreferenceTab.layout =>
                          _supportsTypography ? 'Page layout' : 'Layout',
                        _PreferenceTab.style => 'Templates',
                        _PreferenceTab.appearance => 'Appearance',
                        _PreferenceTab.navigation => 'Navigation',
                        _PreferenceTab.rendering => 'Rendering',
                        _PreferenceTab.preloading => 'Preloading',
                      }),
                    ),
                ],
                onTap: (index) => setState(() => _tab = tabs[index]),
              );
        final body = Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            key: ValueKey((
              _scope,
              _effective.mode,
              _activeTab,
              _effective.webtoonQuality,
            )),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AbsorbPointer(absorbing: _loading, child: _tabContent()),
              if (_scope == SettingsScope.library) ...[
                const SizedBox(height: 24),
                const LText(
                  'Apply these preferences to every series and book in this library, replacing their custom reading preferences.',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('apply-library-defaults'),
                  onPressed: _loading ? null : _applyToLibrary,
                  child: const LText('Apply to all series and books'),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                LText(_message!, key: const Key('reader-settings-message')),
              ],
            ],
          ),
        );
        return Align(
          heightFactor: 1,
          widthFactor: 1,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.modal ? 0 : height,
                maxHeight: height,
              ),
              child: DefaultTabController(
                key: ValueKey(tabs.map((tab) => tab.name).join(',')),
                length: tabs.length,
                initialIndex: tabs.indexOf(_activeTab),
                animationDuration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      fit: widget.modal ? FlexFit.loose : FlexFit.tight,
                      child: short
                          ? SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [header, navigation, body],
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                header,
                                navigation,
                                Flexible(
                                  fit: widget.modal
                                      ? FlexFit.loose
                                      : FlexFit.tight,
                                  child: SingleChildScrollView(
                                    key: PageStorageKey((
                                      'reader-settings',
                                      _activeTab,
                                      _scope,
                                    )),
                                    child: body,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
