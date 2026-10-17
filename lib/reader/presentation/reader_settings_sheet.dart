import 'ebook_style_picker.dart';
import 'ebook_settings_controls.dart';
import 'ebook_presentation.dart';
import 'reader_settings_layout.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/reader_store.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';
import '../domain/webtoon_layout.dart';

enum _PreferenceTab { layout, style, typography, rendering, preloading }

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    required this.store,
    this.manifest,
    this.libraryId,
    this.onSaved,
    this.showSaveAction = true,
    this.qualityOnly = false,
    this.modal = false,
    super.key,
  });
  final VoidCallback? onSaved;
  final bool showSaveAction;
  final bool qualityOnly;
  final bool modal;
  final ReaderStore store;
  final ReaderManifest? manifest;
  final String? libraryId;
  @override
  ReaderSettingsSheetState createState() => ReaderSettingsSheetState();
}

class ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late SettingsScope _scope;
  Map<SettingsScope, ReadingOverrides> _layers = {};
  ReadingOverrides _overrides = const ReadingOverrides();
  bool _loading = true;
  late final double _maximumStripRatio;
  int _generation = 0;
  String? _message;
  _PreferenceTab _tab = _PreferenceTab.layout;
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
          _PreferenceTab.layout,
          if (_supportsTypography) ...[
            _PreferenceTab.style,
            _PreferenceTab.typography,
          ],
          if (widget.manifest != null && !widget.manifest!.isDocument)
            _PreferenceTab.rendering,
          if (widget.manifest != null && _effective.mode == ReadingMode.webtoon)
            _PreferenceTab.preloading,
        ];
  _PreferenceTab get _activeTab => _tabs.contains(_tab) ? _tab : _tabs.first;
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
      final layers = await widget.store.preferenceLayers(
        libraryId: widget.libraryId ?? widget.manifest?.libraryId,
        seriesId: widget.manifest?.seriesId,
        bookId: widget.manifest?.bookId,
      );
      final ebookConfigured = layers.values.any(
        (layer) => layer.mode == ReadingMode.ebook,
      );
      final value =
          layers[scope] ??
          (widget.manifest?.isDocument == true
              ? ReadingOverrides(
                  mode: ReadingMode.ebook,
                  background: ebookConfigured ? null : ReadingBackground.sepia,
                )
              : const ReadingOverrides());
      if (mounted && generation == _generation) {
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

  void _change(String key, Object? value) => setState(() {
    final values = {..._overrides.toJson(), key: value};
    if (key == 'layout') values['spreads'] = null;
    if (key == 'mode' && value != _overrides.mode?.name) {
      if (value == 'ebook') values['background'] = 'sepia';
      for (final field in [
        'direction',
        'fit',
        'spacing',
        'spreads',
        'layout',
      ]) {
        values[field] = null;
      }
    }
    _overrides = ReadingOverrides.fromJson(values);
  });
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
      'background' => settings.background.name,
      'spacing' => settings.spacing.toString(),
      'layout' => settings.layout.name,
      _ => throw ArgumentError('Unknown reading setting'),
    };
    if (!choices.containsKey(raw)) {
      choices = {
        ...choices,
        raw.toString(): context.tr('{0} (custom)', [raw]),
      };
    }
    return DropdownButtonFormField<String>(
      icon: const Icon(InkIcons.caretDown, size: 20),
      key: ValueKey('${_scope.name}-$key-$raw'),
      initialValue: raw.toString(),
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(labelText: context.tr(label)),
      selectedItemBuilder: (context) => [
        for (final label in choices.values)
          ReaderSettingsSelectedValue(context.tr(label)),
      ],
      items: [
        ...choices.entries.map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: LText(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) => _change(
              key,
              key == 'spacing'
                  ? double.parse(value!)
                  : key == 'spreads'
                  ? value == 'true'
                  : value,
            ),
    );
  }

  Widget _imageQuality() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LText(
        'Choose how each image format is displayed. Archive files use the format of each page inside them.',
      ),
      const SizedBox(height: 12),
      for (final format in RasterFormat.values) ...[
        LText(switch (format) {
          RasterFormat.jpeg => 'JPEG images',
          RasterFormat.png => 'PNG images',
          RasterFormat.webp => 'WebP images',
          RasterFormat.other => 'Other images',
        }, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ReaderSettingsGrid(
          children: [
            _qualityChoice<ImageSampling>(
              format,
              'Image scaling',
              ImageSampling.values,
              _effective.imageQuality[format]?.sampling ?? ImageSampling.high,
              (value) => switch (value) {
                ImageSampling.nearest => 'Nearest neighbour',
                ImageSampling.smooth => 'Bilinear',
                ImageSampling.high => 'High quality',
              },
              (value) => RasterQuality(
                sampling: value,
                filter:
                    _effective.imageQuality[format]?.filter ??
                    VisualFilter.original,
              ),
            ),
            _qualityChoice<VisualFilter>(
              format,
              'Visual filter',
              VisualFilter.values,
              _effective.imageQuality[format]?.filter ?? VisualFilter.original,
              (value) => switch (value) {
                VisualFilter.original => 'Original colours',
                VisualFilter.grayscale => 'Grayscale',
                VisualFilter.sepia => 'Sepia',
                VisualFilter.inverted => 'Invert colours',
              },
              (value) => RasterQuality(
                filter: value,
                sampling:
                    _effective.imageQuality[format]?.sampling ??
                    ImageSampling.high,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
      const LText(
        'High quality uses the rendering engine’s best image sampling. Scaling cannot restore details missing from the source.',
      ),
    ],
  );

  Widget _qualityChoice<T extends Enum>(
    RasterFormat format,
    String label,
    List<T> values,
    T current,
    String Function(T) text,
    RasterQuality Function(T) update,
  ) => DropdownButtonFormField<T>(
    key: ValueKey('quality-${format.name}-$label-${current.name}'),
    initialValue: current,
    isExpanded: true,
    itemHeight: null,
    icon: const Icon(InkIcons.caretDown, size: 20),
    decoration: InputDecoration(labelText: context.tr(label)),
    selectedItemBuilder: (context) => [
      for (final value in values)
        ReaderSettingsSelectedValue(context.tr(text(value))),
    ],
    items: [
      for (final value in values)
        DropdownMenuItem(value: value, child: LText(text(value))),
    ],
    onChanged: _loading
        ? null
        : (value) {
            if (value == null) return;
            _change('imageQuality', {
              for (final entry
                  in (_overrides.imageQuality ??
                          const <RasterFormat, RasterQuality>{})
                      .entries)
                entry.key.name: entry.value.toJson(),
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

  /// Commit the editor through its owning setup footer or standalone action.
  Future<void> savePreferences() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.store.saveOverrides(_scope, _id(_scope), _overrides);
      if (mounted) {
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
          _message = 'Unable to save reading preferences.';
        });
      }
    }
  }

  Future<void> _applyToLibrary() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.store.applyLibraryDefaults(
        _id(SettingsScope.library),
        _overrides,
      );
      if (mounted) {
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

  void _reset() => setState(() {
    final values = {..._overrides.toJson()};
    for (final field
        in _showQuality
            ? [
                'imageQuality',
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
                'pageAnimation',
                'ebook',
              ]) {
      values[field] = null;
    }
    if (!_showQuality) {
      values['libraryDefaults'] =
          _scope == SettingsScope.book && widget.manifest?.libraryId != null;
    }
    _overrides = ReadingOverrides.fromJson(values);
  });

  Widget _scopeControl() => DropdownButtonFormField<SettingsScope>(
    key: ValueKey(('scope', _scope)),
    icon: const Icon(InkIcons.caretDown, size: 20),
    initialValue: _scope,
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: context.tr('Apply to')),
    items: [
      const DropdownMenuItem(
        value: SettingsScope.global,
        child: LText('Global'),
      ),
      if (widget.manifest?.libraryId != null)
        const DropdownMenuItem(
          value: SettingsScope.library,
          child: LText('Library'),
        ),
      if (widget.manifest?.seriesId != null)
        const DropdownMenuItem(
          value: SettingsScope.series,
          child: LText('Series'),
        ),
      if (widget.manifest != null)
        const DropdownMenuItem(
          value: SettingsScope.book,
          child: LText('This book'),
        ),
    ],
    onChanged: _loading ? null : (scope) => _load(scope!),
  );

  Widget _layoutControls() {
    // A global ebook default must not expose typography for a raster volume.
    final mode = _effective.mode == ReadingMode.ebook && _rasterControls
        ? ReadingMode.comics
        : _effective.mode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReaderSettingsGrid(
          children: [
            if (widget.manifest?.isDocument != true)
              _select('Mode', 'mode', {
                'manga': 'Manga',
                'comics': 'Comics',
                'webtoon': 'Webtoon',
                if (widget.manifest == null ||
                    _effective.mode == ReadingMode.ebook)
                  'ebook': 'Ebooks',
              }),
            _select('Background', 'background', {
              'black': 'Black',
              'white': 'White',
              'sepia': 'Sepia',
              if (mode == ReadingMode.ebook) ...{
                'ivory': 'Ivory',
                'sage': 'Soft sage',
                'mist': 'Blue mist',
                'slate': 'Slate night',
              },
            }),
            if (widget.manifest?.documentType == 'application/pdf')
              _select('Fit', 'fit', {'page': 'Fit page', 'width': 'Fit width'}),
          ],
        ),
        const SizedBox(height: 20),
        if (mode != ReadingMode.ebook)
          ReaderSettingsGrid(
            children: [
              if (mode != ReadingMode.webtoon)
                _select('Direction', 'direction', {
                  'leftToRight': 'Left to right',
                  'rightToLeft': 'Right to left',
                  'vertical': 'Vertical pages',
                }),
              _select(
                'Fit',
                'fit',
                mode == ReadingMode.webtoon
                    ? {
                        'comfort': 'Comfortable width',
                        'width': 'Full width',
                        'page': 'Comfortable width (legacy)',
                      }
                    : {'page': 'Fit page', 'width': 'Fit width'},
              ),
              if (mode != ReadingMode.webtoon)
                _select('Page layout', 'layout', {
                  'single': 'Single page',
                  'doublePage': 'Two pages',
                  'automatic': 'Automatic landscape spreads',
                }),
              _select('Page spacing', 'spacing', {
                for (final n in [0, 4, 8, 12, 16, 24, 32, 48, 64])
                  '$n.0': context.tr('{0} px', [n]),
              }),
            ],
          ),
        if (mode == ReadingMode.ebook) ...[
          EbookSettingsControls(
            section: EbookControlsSection.layout,
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const LText('Page turn animation'),
            value: _effective.pageAnimation,
            onChanged: (value) => _change('pageAnimation', value),
          ),
      ],
    );
  }

  Widget _tabContent() => switch (_activeTab) {
    _PreferenceTab.layout => _layoutControls(),
    _PreferenceTab.style => EbookStylePicker(
      settings: _effective,
      onSelected: (style) =>
          setState(() => _overrides = style.apply(_overrides)),
    ),
    _PreferenceTab.typography => EbookSettingsControls(
      section: EbookControlsSection.typography,
      settings: _effective.ebook,
      onChanged: (key, value) =>
          _change('ebook', {...?_overrides.ebook, key: value}),
    ),
    _PreferenceTab.rendering => _imageQuality(),
    _PreferenceTab.preloading => _webtoonQuality(context),
  };

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: 12,
      overflowSpacing: 8,
      children: [
        TextButton(
          onPressed: _loading ? null : _reset,
          child: const LText('Reset to default'),
        ),
        if (widget.showSaveAction)
          FilledButton(
            onPressed: _loading ? null : savePreferences,
            child: const LText('Save'),
          ),
      ],
    ),
  );

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
                math.min(MediaQuery.sizeOf(context).height * .86, 520 * scale),
              )
            : available;
        final height = widget.modal && tabs.length == 1
            ? math.min(preferredHeight, 360 * scale)
            : preferredHeight;
        // Large type can make the header/actions taller than a phone sheet.
        // Let the whole editor scroll then; ordinary sizes keep actions pinned.
        final short = scale > 1.3 || height < 420;
        final title = LText(
          widget.qualityOnly ? 'Quality' : 'Reading preferences',
          style: Theme.of(context).textTheme.titleLarge,
        );
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: LayoutBuilder(
            builder: (context, headerConstraints) {
              final scope = widget.manifest != null && widget.libraryId == null;
              final wide = headerConstraints.maxWidth >= 520 * scale;
              final close = widget.modal
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonTooltip,
                      icon: const Icon(InkIcons.x),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : widget.manifest == null && widget.libraryId == null
                  ? LText(
                      'Global',
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  : const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: title),
                      if (scope && wide) ...[
                        const SizedBox(width: 16),
                        SizedBox(width: 200, child: _scopeControl()),
                        const SizedBox(width: 8),
                      ],
                      close,
                    ],
                  ),
                  if (scope && !wide) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 280 * scale,
                        child: _scopeControl(),
                      ),
                    ),
                  ],
                  if (_loading) const LinearProgressIndicator(),
                ],
              );
            },
          ),
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
                        _PreferenceTab.layout => 'Layout',
                        _PreferenceTab.style => 'Reading style',
                        _PreferenceTab.typography => 'Typography',
                        _PreferenceTab.rendering => 'Rendering',
                        _PreferenceTab.preloading => 'Preloading',
                      }),
                    ),
                ],
                onTap: (index) => setState(() => _tab = tabs[index]),
              );
        final body = Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                LText(_message!),
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
            child: SizedBox(
              height: height,
              child: DefaultTabController(
                key: ValueKey(tabs.map((tab) => tab.name).join(',')),
                length: tabs.length,
                initialIndex: tabs.indexOf(_activeTab),
                child: short
                    ? SingleChildScrollView(
                        child: Column(
                          // Refresh action semantics when conditional controls
                          // move them in short windows.
                          key: ValueKey((
                            _scope,
                            _effective.mode,
                            _activeTab,
                            _effective.webtoonQuality,
                          )),
                          mainAxisSize: MainAxisSize.min,
                          children: [header, navigation, body, _footer()],
                        ),
                      )
                    : Column(
                        children: [
                          header,
                          navigation,
                          Expanded(
                            child: SingleChildScrollView(
                              key: PageStorageKey((
                                'reader-settings',
                                _activeTab,
                                _scope,
                              )),
                              child: body,
                            ),
                          ),
                          _footer(),
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
