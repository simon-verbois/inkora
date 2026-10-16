import 'reading_colors.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/icons/inkora_icons.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../data/reader_repository.dart';
import '../application/reader_network_policy.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';
import '../domain/webtoon_layout.dart';
import '../domain/reader_trace.dart';
import '../domain/paged_layout.dart';
import 'reader_page_image.dart';
import 'webtoon_scroll_physics.dart';
import 'reader_image_provider.dart';

class ReaderViewport extends StatefulWidget {
  const ReaderViewport({
    required this.reader,
    required this.settings,
    required this.saveLocator,
    this.controlsVisible = true,
    this.onToggleControls,
    this.onLocatorChanged,
    this.onToggleSpreadOffset,
    super.key,
  });
  final OpenReader reader;
  final ReadingSettings settings;
  final Future<void> Function(ReaderLocator) saveLocator;
  final bool controlsVisible;
  final VoidCallback? onToggleControls;
  final ValueChanged<ReaderLocator>? onLocatorChanged;

  /// Flips the book's one-page spread offset (persisted by the screen).
  final VoidCallback? onToggleSpreadOffset;
  @override
  State<ReaderViewport> createState() => _ReaderViewportState();
}

class _ReaderViewportState extends State<ReaderViewport>
    with WidgetsBindingObserver {
  late ReaderLocator _locator;
  late final ValueNotifier<ReaderLocator> _controlPosition;
  final _focus = FocusNode();
  Timer? _saveTimer;
  StreamSubscription<ReaderNetworkSnapshot>? _policy;
  Future<void> _writes = Future.value();
  bool _saveFailed = false;
  PagedLayout? _pagedLayout;
  int? _scrub;

  @override
  void initState() {
    super.initState();
    _locator = widget.reader.locator;
    _controlPosition = ValueNotifier(_locator);
    WidgetsBinding.instance.addObserver(this);
    if (widget.reader.prefetch != null) {
      widget.reader.prefetch!.policy.paused = true;
      _watchPolicy();
    }
    ReaderDecodedCache.retainRevision(
      widget.reader.manifest.accountId,
      widget.reader.manifest.bookId,
      widget.reader.manifest.revision,
    );
  }

  /// Android pushes policy changes; other platforms poll inside the stream.
  void _watchPolicy() {
    unawaited(_policy?.cancel());
    _policy = ReaderNetworkPolicy.watch().listen(_networkPolicy);
  }

  void _networkPolicy(ReaderNetworkSnapshot snapshot) {
    if (mounted) {
      final policy = widget.reader.prefetch?.policy;
      final changed =
          policy != null &&
          (policy.constrained != snapshot.constrained ||
              policy.paused != snapshot.paused);
      widget.reader.prefetch?.configureNetwork(
        constrained: snapshot.constrained,
        paused: snapshot.paused,
      );
      if (changed) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.reader.prefetch?.suspend(state != AppLifecycleState.resumed);
    if (widget.reader.prefetch == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_policy == null) _watchPolicy();
    } else {
      // No policy work while the reader is not visible.
      unawaited(_policy?.cancel());
      _policy = null;
    }
  }

  void _save() {
    final locator = _locator;
    final saveLocator = widget.saveLocator;
    _writes = _writes.then((_) => saveLocator(locator)).catchError((Object _) {
      if (mounted && !_saveFailed) setState(() => _saveFailed = true);
    });
  }

  void _position(ReaderLocator locator, {bool immediate = false}) {
    final pageChanged = locator.pageIndex != _locator.pageIndex;
    if (immediate || widget.settings.mode != ReadingMode.webtoon) {
      if (pageChanged || immediate) {
        setState(() => _locator = locator);
      } else {
        _locator = locator;
      }
    } else {
      _locator = locator;
    }
    if (pageChanged || immediate) _controlPosition.value = locator;
    widget.onLocatorChanged?.call(locator);
    _saveTimer?.cancel();
    if (immediate || widget.settings.mode != ReadingMode.webtoon) {
      _save();
    } else {
      _saveTimer = Timer(const Duration(milliseconds: 180), _save);
    }
  }

  void _jump(int page) => _position(
    ReaderLocator(page.clamp(0, widget.reader.manifest.pages.length - 1)),
    immediate: true,
  );
  void _advance(int delta) {
    if (widget.settings.mode == ReadingMode.webtoon || _pagedLayout == null) {
      _jump(_locator.pageIndex + delta);
    } else {
      _jump(_pagedLayout!.adjacent(_locator.pageIndex, delta));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_policy?.cancel());
    _save();
    widget.reader.prefetch?.suspend(true);
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    _controlPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.reader.manifest.pages.length;
    final settings = widget.settings;
    final background = switch (settings.background) {
      ReadingBackground.black => Colors.black,
      ReadingBackground.white => Colors.white,
      ReadingBackground.sepia => const Color(0xffeee2c8),
      final background => background.paperColor,
    };
    return LayoutBuilder(
      builder: (context, viewport) {
        final isWebtoon = settings.mode == ReadingMode.webtoon;
        final doubles = settings.useDoublePages(
          viewport.maxWidth,
          viewport.maxHeight,
        );
        final offset = settings.spreadOffset ? 1 : 0;
        if (!isWebtoon &&
            (_pagedLayout?.dimensions != widget.reader.manifest.pages ||
                _pagedLayout?.doublePages != doubles ||
                _pagedLayout?.offset != offset)) {
          _pagedLayout = PagedLayout(
            widget.reader.manifest.pages,
            doublePages: doubles,
            offset: offset,
          );
        }
        return KeyboardListener(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            if (event.logicalKey == LogicalKeyboardKey.space ||
                (event.logicalKey == LogicalKeyboardKey.escape &&
                    widget.controlsVisible)) {
              widget.onToggleControls?.call();
              return;
            }
            final reverse = settings.direction == ReadingDirection.rightToLeft;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _advance(reverse ? -1 : 1);
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _advance(reverse ? 1 : -1);
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.pageDown) {
              _advance(1);
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.pageUp) {
              _advance(-1);
            }
            if (event.logicalKey == LogicalKeyboardKey.home) _jump(0);
            if (event.logicalKey == LogicalKeyboardKey.end) _jump(count - 1);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggleControls,
                child: ColoredBox(
                  color: background,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return settings.mode == ReadingMode.webtoon
                          ? _WebtoonViewport(
                              key: ValueKey(
                                'webtoon-${widget.reader.manifest.revision}',
                              ),
                              reader: widget.reader,
                              settings: settings,
                              locator: _locator,
                              onPosition: _position,
                            )
                          : _PagedViewport(
                              key: ValueKey(
                                'paged-${widget.reader.manifest.revision}-${settings.direction.name}-${_pagedLayout!.groups.length}',
                              ),
                              reader: widget.reader,
                              settings: settings,
                              locator: _locator,
                              layout: _pagedLayout!,
                              onPosition: _position,
                              onTap: widget.onToggleControls,
                            );
                    },
                  ),
                ),
              ),
              if (widget.controlsVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<ReaderLocator>(
                    valueListenable: _controlPosition,
                    builder: (context, position, _) {
                      final pages = isWebtoon
                          ? [position.pageIndex]
                          : _pagedLayout!.pagesFor(position.pageIndex);
                      final hasPrevious = isWebtoon
                          ? position.pageIndex > 0
                          : _pagedLayout!.groupFor(position.pageIndex) > 0;
                      final hasNext = isWebtoon
                          ? position.pageIndex < count - 1
                          : _pagedLayout!.groupFor(position.pageIndex) <
                                _pagedLayout!.groups.length - 1;
                      return Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_saveFailed)
                                const LText(
                                  'Reading position could not be saved.',
                                ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: context.tr("Previous page"),
                                    onPressed: hasPrevious
                                        ? () => _advance(-1)
                                        : null,
                                    icon: const Icon(InkIcons.caretLeft),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      key: const Key('reader-page-slider'),
                                      min: 0,
                                      max: math.max(1, count - 1).toDouble(),
                                      value: (_scrub ?? _locator.pageIndex)
                                          .toDouble(),
                                      divisions: count > 1 ? count - 1 : null,
                                      label: context.tr('{0}', [
                                        (_scrub ?? _locator.pageIndex) + 1,
                                      ]),
                                      // Scrubbing previews only; the page load,
                                      // locator write and jump happen on release.
                                      onChanged: count > 1
                                          ? (value) => setState(
                                              () => _scrub = value.round(),
                                            )
                                          : null,
                                      onChangeEnd: count > 1
                                          ? (value) {
                                              _scrub = null;
                                              _jump(value.round());
                                            }
                                          : null,
                                    ),
                                  ),
                                  // One tap re-pairs spreads by one page; shown
                                  // only when two pages can share the screen.
                                  if (!isWebtoon &&
                                      doubles &&
                                      widget.onToggleSpreadOffset != null)
                                    IconButton(
                                      key: const Key('reader-spread-offset'),
                                      tooltip: context.tr(
                                        settings.spreadOffset
                                            ? 'Pair pages from the first page'
                                            : 'Shift page pairing by one',
                                      ),
                                      isSelected: settings.spreadOffset,
                                      onPressed: widget.onToggleSpreadOffset,
                                      icon: const Icon(
                                        InkIcons.arrowsLeftRight,
                                      ),
                                    ),
                                  LText(
                                    pages.length > 1
                                        ? context.tr('{0}–{1} / {2}', [
                                            pages.first + 1,
                                            pages.last + 1,
                                            count,
                                          ])
                                        : context.tr('{0} / {1}', [
                                            _locator.pageIndex + 1,
                                            count,
                                          ]),
                                    key: const Key('reader-position'),
                                  ),
                                  IconButton(
                                    tooltip: context.tr("Next page"),
                                    onPressed: hasNext
                                        ? () => _advance(1)
                                        : null,
                                    icon: const Icon(InkIcons.caretRight),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Spreads decoded ahead of the current one in the reading direction.
const pagedDecodeAhead = 3;

class _PagedViewport extends StatefulWidget {
  const _PagedViewport({
    required this.reader,
    required this.settings,
    required this.locator,
    required this.layout,
    required this.onPosition,
    required this.onTap,
    super.key,
  });
  final OpenReader reader;
  final ReadingSettings settings;
  final ReaderLocator locator;
  final PagedLayout layout;
  final void Function(ReaderLocator) onPosition;
  final VoidCallback? onTap;
  @override
  State<_PagedViewport> createState() => _PagedViewportState();
}

class _PagedViewportState extends State<_PagedViewport> {
  late PageController _controller;
  bool _zoomed = false;
  Timer? _warmTimer;
  bool _decoding = false;
  int _warmGeneration = 0;
  Object? _lastWarm;
  void _turn(int delta) {
    final current = widget.layout.groupFor(widget.locator.pageIndex);
    final next = (current + delta).clamp(0, widget.layout.groups.length - 1);
    if (next != current) {
      unawaited(
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _prefetch(double width, double height, double pixelRatio) {
    final session = widget.reader.prefetch;
    if (session == null) return;
    session.suspend(false);
    final group = widget.layout.pagesFor(widget.locator.pageIndex);
    session.update(group.first, visiblePages: group.length);
    final target = (
      group.first,
      width,
      height,
      pixelRatio,
      widget.settings.spacing,
      widget.settings.fit,
      session.policy.direction,
    );
    if (_lastWarm == target) return;
    _lastWarm = target;
    _warmTimer?.cancel();
    final generation = ++_warmGeneration;
    final warmed = <int>{};
    // Decode the next spreads ahead (nearest first) so fast consecutive swipes
    // land on ready images; the adjacent spreads are also mounted by the
    // PageView. One speculative codec at a time; bytes are awaited from the
    // encoded prefetch, and results from a stale generation are evicted.
    final current = widget.layout.groupFor(widget.locator.pageIndex);
    final step = session.policy.direction;
    final targets = [
      for (var distance = 1; distance <= pagedDecodeAhead; distance++)
        if (current + step * distance >= 0 &&
            current + step * distance < widget.layout.groups.length)
          for (final page in widget.layout.groups[current + step * distance])
            (group: current + step * distance, page: page),
    ];
    _warmTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) async {
      if (!mounted || generation != _warmGeneration || timer.tick > 200) {
        timer.cancel();
        return;
      }
      if (_decoding) return;
      // Nearest page whose encoded bytes are available and not yet warmed.
      final ready = targets
          .where((target) => !warmed.contains(target.page))
          .map(
            (target) => (
              target: target,
              bytes: session.memory.get(
                widget.reader.manifest.key(target.page),
              ),
            ),
          )
          .where((entry) => entry.bytes != null)
          .firstOrNull;
      if (ready == null) {
        if (warmed.length == targets.length) timer.cancel();
        return;
      }
      final groupPages = widget.layout.groups[ready.target.group];
      final geometry = SpreadGeometry(
        groupPages.map((i) => widget.reader.manifest.pages[i]).toList(),
        width,
        height,
        spacing: widget.settings.spacing,
        fitWidth: widget.settings.fit == ReadingFit.width,
      );
      // Same decode size/key as the mounted ReaderPageImage will request.
      final size = readerDecodeSize(
        widget.reader.manifest.pages[ready.target.page],
        geometry.widths[groupPages.indexOf(ready.target.page)] * pixelRatio,
      );
      final provider = ReaderImageProvider(
        ready.bytes!,
        size.width,
        size.height,
        onDecoded: session.policy.network.observeDecode,
      );
      _decoding = true;
      await precacheImage(provider, context, onError: (_, _) {});
      _decoding = false;
      warmed.add(ready.target.page);
      if (!mounted || generation != _warmGeneration) {
        ReaderDecodedCache.evict(provider.imageKey);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.layout.groupFor(widget.locator.pageIndex),
    );
  }

  @override
  void didUpdateWidget(_PagedViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = widget.layout.groupFor(widget.locator.pageIndex);
    if (_controller.hasClients && _controller.page?.round() != page) {
      _zoomed = false;
      // The locator already names this group (re-pairing, rotation, slider):
      // the jump runs during build, so it must not report a page change back
      // to the parent (that would call setState mid-build).
      _programmaticJump = true;
      try {
        _controller.jumpToPage(page);
      } finally {
        _programmaticJump = false;
      }
    }
  }

  bool _programmaticJump = false;

  @override
  void dispose() {
    _warmTimer?.cancel();
    _warmGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prefetch(
            constraints.maxWidth,
            constraints.maxHeight,
            MediaQuery.devicePixelRatioOf(context),
          );
        }
      });
      return PageView.builder(
        key: const Key('paged-reader'),
        controller: _controller,
        // Keep the neighbouring spreads mounted (and decoding) so a swipe
        // reveals finished images instead of starting work mid-gesture.
        allowImplicitScrolling: true,
        itemCount: widget.layout.groups.length,
        reverse: widget.settings.direction == ReadingDirection.rightToLeft,
        scrollDirection: widget.settings.direction == ReadingDirection.vertical
            ? Axis.vertical
            : Axis.horizontal,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        onPageChanged: (page) {
          if (_programmaticJump) return;
          _zoomed = false;
          widget.onPosition(ReaderLocator(widget.layout.groups[page].last));
        },
        itemBuilder: (context, group) {
          final indexes = widget.layout.groups[group];
          return _ZoomSpread(
            key: ValueKey(indexes.first),
            reader: widget.reader,
            indexes: indexes,
            fit: widget.settings.fit,
            imageQuality: widget.settings.imageQuality,
            spacing: widget.settings.spacing,
            reverse: widget.settings.direction == ReadingDirection.rightToLeft,
            visible: widget.layout.groupFor(widget.locator.pageIndex) == group,
            direction: widget.settings.direction,
            onTap: widget.onTap,
            onSwipe: _turn,
            onZoom: (zoomed) {
              if (mounted && _zoomed != zoomed) {
                setState(() => _zoomed = zoomed);
              }
            },
          );
        },
      );
    },
  );
}

class _ZoomSpread extends StatefulWidget {
  const _ZoomSpread({
    required this.reader,
    required this.imageQuality,
    required this.indexes,
    required this.spacing,
    required this.reverse,
    required this.fit,
    required this.onZoom,
    required this.onTap,
    required this.visible,
    required this.direction,
    required this.onSwipe,
    super.key,
  });
  final OpenReader reader;
  final Map<RasterFormat, RasterQuality> imageQuality;
  final List<int> indexes;
  final double spacing;
  final bool reverse;
  final ReadingFit fit;
  final ValueChanged<bool> onZoom;
  final bool visible;
  final ReadingDirection direction;
  final ValueChanged<int> onSwipe;
  final VoidCallback? onTap;
  @override
  State<_ZoomSpread> createState() => _ZoomSpreadState();
}

class _ZoomSpreadState extends State<_ZoomSpread> {
  final _transform = TransformationController();
  Offset _pan = Offset.zero;
  int _pointers = 0;
  bool _startedZoomed = false;
  Size? _viewportSize;
  ReadingFit? _fittedMode;

  /// Settled zoom step used for decode resolution; updated when a gesture
  /// ends (not per pinch frame) and reset when the transform returns to 1.
  double _decodeZoom = 1;
  @override
  void initState() {
    super.initState();
    _transform.addListener(_zoom);
  }

  void _zoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (!zoomed && _decodeZoom != 1) setState(() => _decodeZoom = 1);
    widget.onZoom(zoomed);
  }

  void _settleZoom() {
    final step = zoomDecodeStep(_transform.value.getMaxScaleOnAxis());
    if (step != _decodeZoom) setState(() => _decodeZoom = step);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_viewportSize != null &&
          (_viewportSize != size || _fittedMode != widget.fit)) {
        // Keep page/image state while discarding a transform tied to the old viewport.
        _transform.removeListener(_zoom);
        _transform.value = Matrix4.identity();
        _transform.addListener(_zoom);
        _decodeZoom = 1;
        _pan = Offset.zero;
        _pointers = 0;
        _startedZoomed = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onZoom(false);
        });
      }
      _viewportSize = size;
      _fittedMode = widget.fit;
      final pages = widget.indexes
          .map((i) => widget.reader.manifest.pages[i])
          .toList();
      final geometry = SpreadGeometry(
        pages,
        constraints.maxWidth,
        constraints.maxHeight,
        spacing: widget.spacing,
        fitWidth: widget.fit == ReadingFit.width,
      );
      final order = [for (var i = 0; i < widget.indexes.length; i++) i];
      if (widget.reverse) order.sort((a, b) => b.compareTo(a));
      final spread = SizedBox(
        key: ValueKey('spread-${widget.indexes.first}'),
        width: geometry.width,
        height: geometry.height,
        child: Row(
          children: [
            for (var slot = 0; slot < order.length; slot++) ...[
              if (slot > 0) SizedBox(width: geometry.gap),
              SizedBox(
                width: geometry.widths[order[slot]],
                height: geometry.height,
                child: ReaderPageImage(
                  key: ValueKey(
                    widget.reader.manifest.key(widget.indexes[order[slot]]),
                  ),
                  manifest: widget.reader.manifest,
                  index: widget.indexes[order[slot]],
                  source: widget.reader.source,
                  imageQuality: widget.imageQuality,
                  visible: widget.visible,
                  prefetch: widget.reader.prefetch,
                  telemetry: widget.reader.telemetry,
                  fit: widget.fit,
                  edgeToEdge: true,
                  zoom: widget.visible ? _decodeZoom : 1,
                ),
              ),
            ],
          ],
        ),
      );
      return InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        onInteractionStart: (details) {
          _pan = Offset.zero;
          _pointers = details.pointerCount;
          _startedZoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
        },
        onInteractionUpdate: (details) {
          _pointers = math.max(_pointers, details.pointerCount);
          _pan += details.focalPointDelta;
        },
        onInteractionEnd: (_) {
          _settleZoom();
          // InteractiveViewer can win the gesture arena before PageView. Route
          // its unzoomed one-finger drag as a page turn; pinch/pan stays local.
          if (_startedZoomed ||
              _pointers != 1 ||
              _transform.value.getMaxScaleOnAxis() > 1.01) {
            return;
          }
          final vertical = widget.direction == ReadingDirection.vertical;
          final primary = vertical ? _pan.dy : _pan.dx;
          final secondary = vertical ? _pan.dx : _pan.dy;
          final extent = vertical
              ? constraints.maxHeight
              : constraints.maxWidth;
          if (primary.abs() < math.min(80, extent * .15) ||
              primary.abs() <= secondary.abs()) {
            return;
          }
          final forward = widget.direction == ReadingDirection.rightToLeft
              ? primary > 0
              : primary < 0;
          widget.onSwipe(forward ? 1 : -1);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox.expand(
            child: widget.fit == ReadingFit.width
                ? SingleChildScrollView(child: spread)
                : Center(child: spread),
          ),
        ),
      );
    },
  );
}

class _WebtoonViewport extends StatefulWidget {
  const _WebtoonViewport({
    required this.reader,
    required this.settings,
    required this.locator,
    required this.onPosition,
    super.key,
  });
  final OpenReader reader;
  final ReadingSettings settings;
  final ReaderLocator locator;
  final ValueChanged<ReaderLocator> onPosition;
  @override
  State<_WebtoonViewport> createState() => _WebtoonViewportState();
}

class _WebtoonViewportState extends State<_WebtoonViewport> {
  ScrollController? _controller;
  WebtoonLayout? _layout;
  double _viewportHeight = 0;
  bool _restoring = false;
  ({int first, int last})? _visibleRange;
  ({int first, int last})? _preparedRange;
  double _cacheExtent = 0;
  ReaderLocator? _lastReported;
  ({int page, int visible, double offset, WebtoonLayout layout})? _planned;
  void _scroll() {
    if (_restoring || !mounted || !_controller!.hasClients) return;
    final offset = _controller!.offset;
    ReaderTrace.sink?.call('scroll', null, {
      'offset': offset,
      'cacheExtent': _cacheExtent,
      'viewport': _viewportHeight,
      'velocity': widget.reader.prefetch?.policy.pixelsPerSecond,
    });
    final locator = _layout!.locate(offset);
    _lastReported = locator;
    widget.onPosition(locator);
    final visiblePages = _layout!.visible(offset, _viewportHeight);
    final visible = visiblePages.length;
    final range = (first: visiblePages.first, last: visiblePages.last);
    // Replanning allocates demand lists and sweeps work; per-pixel scroll
    // events only replan on page/visibility changes or ~1/8 viewport motion
    // (still fine-grained enough for velocity and reversal detection).
    final planned = _planned;
    if (planned == null ||
        !identical(planned.layout, _layout) ||
        planned.page != locator.pageIndex ||
        planned.visible != visible ||
        (planned.offset - offset).abs() >= _viewportHeight / 8) {
      _planned = (
        page: locator.pageIndex,
        visible: visible,
        offset: offset,
        layout: _layout!,
      );
      widget.reader.prefetch?.suspend(false);
      widget.reader.prefetch?.update(
        locator.pageIndex,
        layout: _layout,
        offset: offset,
        viewportHeight: _viewportHeight,
        visiblePages: visible,
      );
    }
    final prepared = _layout!.prepared(offset, _viewportHeight, _cacheExtent);
    final preparedRange = (first: prepared.first, last: prepared.last);
    // A newly intersecting prepared strip can change the memory allowance.
    // Refit at that boundary, before layout mounts it, rather than per pixel.
    if (range != _visibleRange || preparedRange != _preparedRange) {
      setState(() => _visibleRange = range);
    }
  }

  @override
  void didUpdateWidget(_WebtoonViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.locator, _lastReported)) return;
    if (_layout != null &&
        _controller!.hasClients &&
        (_layout!.offsetFor(widget.locator) - _controller!.offset).abs() > 1) {
      _restoring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller!.hasClients) return;
        _controller!.jumpTo(
          _layout!
              .offsetFor(widget.locator)
              .clamp(0.0, _controller!.position.maxScrollExtent),
        );
        _restoring = false;
        _scroll();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewportHeight = constraints.maxHeight;
      final readingWidth = WebtoonLayout.readingWidth(
        constraints.maxWidth,
        constraints.maxHeight,
        fullWidth: widget.settings.fit == ReadingFit.width,
      );
      if (_layout == null ||
          (_layout!.width - readingWidth).abs() > .01 ||
          _layout!.spacing != widget.settings.spacing) {
        final previous = _layout != null && _controller!.hasClients
            ? _layout!.locate(_controller!.offset)
            : widget.locator;
        _layout = WebtoonLayout(
          widget.reader.manifest.pages,
          readingWidth,
          widget.settings.spacing,
        );
        final visible = _layout!.visible(
          _layout!.offsetFor(previous),
          constraints.maxHeight,
        );
        _visibleRange = (first: visible.first, last: visible.last);
        if (_controller == null) {
          _controller = ScrollController(
            initialScrollOffset: _layout!.offsetFor(previous),
          )..addListener(_scroll);
        } else {
          _restoring = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_controller!.hasClients) return;
            _controller!.jumpTo(
              _layout!
                  .offsetFor(previous)
                  .clamp(0.0, _controller!.position.maxScrollExtent),
            );
            _restoring = false;
            _scroll();
          });
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scroll();
      });
      final currentOffset = _controller!.hasClients
          ? _controller!.offset
          : _layout!.offsetFor(widget.locator);
      final visiblePages = _layout!
          .visible(currentOffset, _viewportHeight)
          .toSet();
      // Quality preset/custom sliders resolved against this device's pixels.
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final budget = WebtoonBudget.resolve(
        widget.settings.webtoonProfile,
        physicalWidth: readingWidth * pixelRatio,
        physicalHeight: constraints.maxHeight * pixelRatio,
        maximumStripScreens: _layout!.maximumScreenSpan(_viewportHeight),
      );
      _cacheExtent =
          widget.reader.prefetch?.policy.paused == true ||
              widget.reader.prefetch?.policy.constrained == true
          ? 0
          : _layout!.cacheExtent(
              currentOffset,
              _viewportHeight,
              // The initial quality estimate is conservative about whole-strip
              // overhang. Fit the requested distance against the actual strip
              // allowances here instead of discarding available decode lead.
              preloadScreens: widget.settings.webtoonProfile.preloadScreens,
              budget: budget,
            );
      final prepared = _layout!.prepared(
        currentOffset,
        _viewportHeight,
        _cacheExtent,
      );
      _preparedRange = (first: prepared.first, last: prepared.last);
      ReaderTrace.sink?.call('window', null, {
        'offset': currentOffset,
        'cacheExtent': _cacheExtent,
        'visibleFirst': visiblePages.first,
        'visibleLast': visiblePages.last,
        'preparedFirst': prepared.first,
        'preparedLast': prepared.last,
        'perScreenBytes': budget.perScreenBytes,
        'memoryBytes': budget.memoryBytes,
        'paused': widget.reader.prefetch?.policy.paused,
        'constrained': widget.reader.prefetch?.policy.constrained,
      });
      return Center(
        child: SizedBox(
          width: readingWidth,
          child: ListView.builder(
            key: const Key('webtoon-reader'),
            physics: const WebtoonScrollPhysics(),
            controller: _controller,
            padding: EdgeInsets.zero,
            scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
            addAutomaticKeepAlives: false,
            itemCount: widget.reader.manifest.pages.length,
            itemExtentBuilder: (index, _) =>
                _layout!.height(index) + widget.settings.spacing,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: widget.settings.spacing),
              child: ReaderPageImage(
                key: ValueKey(widget.reader.manifest.key(index)),
                manifest: widget.reader.manifest,
                index: index,
                source: widget.reader.source,
                imageQuality: widget.settings.imageQuality,
                prefetch: widget.reader.prefetch,
                telemetry: widget.reader.telemetry,
                fit: ReadingFit.width,
                edgeToEdge: true,
                visible: visiblePages.contains(index),
                decodeBudget: _layout!.decodeBudget(
                  index,
                  _viewportHeight,
                  perScreenBytes: budget.perScreenBytes,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
