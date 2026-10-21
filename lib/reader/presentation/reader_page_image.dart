import '../../app/theme/inkora_theme.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/widgets/image_enhancement.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/failure_kind.dart';
import '../domain/page_source.dart';
import '../domain/reader_manifest.dart';
import '../domain/reading_settings.dart';
import '../domain/reader_telemetry.dart';
import '../domain/reader_trace.dart';
import 'reader_paint_probe.dart';
import '../data/prefetch_session.dart';
import '../data/page_network_gate.dart';
import 'reader_image_provider.dart';
import 'reader_image_effects.dart';

/// Zoomed pages get their own decoded allowance (per visible page), so a
/// pinch re-decode never borrows from the normal reading budget.
const zoomDecodeBudget = 16 * 1024 * 1024;

/// Pinch scale buckets: a re-decode happens only when crossing a step.
double zoomDecodeStep(double scale) =>
    scale < 1.5 ? 1 : math.min(4, scale.roundToDouble());

/// The codec receives bounded dimensions even for extremely tall source pages.
({int width, int height}) readerDecodeSize(
  PageDimensions page,
  double physicalWidth, {
  int budgetBytes = 8 * 1024 * 1024,
  double maximumWidth = 2048,
}) {
  final width = math.min(
    page.width.toDouble(),
    math.min(physicalWidth, maximumWidth),
  );
  final height = width / page.aspectRatio;
  final scale = math.min(
    math.min(1.0, 8192 / height),
    math.sqrt(budgetBytes / (width * height * 4)),
  );
  return (
    width: math.max(1, (width * scale).floor()),
    height: math.max(1, (height * scale).floor()),
  );
}

class ReaderPageImage extends StatefulWidget {
  const ReaderPageImage({
    required this.manifest,
    required this.index,
    required this.source,
    this.fit = ReadingFit.page,
    this.decodeBudget = 8 * 1024 * 1024,
    this.visible = true,
    this.prefetch,
    this.telemetry,
    this.zoom = 1,
    this.edgeToEdge = false,
    this.imageQuality = const {},
    super.key,
  });
  final ReaderManifest manifest;
  final int index;
  final PageSource source;
  final ReadingFit fit;
  final int decodeBudget;
  final bool visible;
  final PrefetchSession? prefetch;
  final ReaderTelemetry? telemetry;

  /// Settled pinch step (see [zoomDecodeStep]); above 1 the page re-decodes
  /// at zoomed resolution within [zoomDecodeBudget], capped by the source.
  final double zoom;

  /// The caller already fitted the source ratio (spread slots/webtoon strips).
  /// Fill that slot to avoid letterboxing from rounded codec dimensions.
  final bool edgeToEdge;
  final Map<RasterFormat, RasterQuality> imageQuality;
  @override
  State<ReaderPageImage> createState() => _ReaderPageImageState();
}

class _ReaderPageImageState extends State<ReaderPageImage> {
  CancellationController? _cancellation;
  late Future<EncodedPage> _page;
  final _intent = Stopwatch();
  bool _presented = false;
  bool _placeholder = false;
  bool _hasFrame = false;
  @override
  void initState() {
    super.initState();
    ReaderTrace.sink?.call('mount', widget.index, {'visible': widget.visible});
    _load();
  }

  @override
  void didUpdateWidget(ReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom > 1 && widget.zoom != oldWidget.zoom) _releaseZoom();
    if (oldWidget.visible != widget.visible) {
      ReaderTrace.sink?.call('visibility', widget.index, {
        'visible': widget.visible,
        'hasFrame': _hasFrame,
      });
    }
    if (!oldWidget.visible && widget.visible) {
      widget.prefetch?.foreground(widget.manifest.key(widget.index));
      _intent.reset();
      _intent.start();
      _presented = false;
      _placeholder = false;
      // Promote pending acquisition through the shared source. A decoded page
      // keeps its existing future and frame when it enters the screen.
      if (!_hasFrame && widget.source is PrioritizedPageSource) {
        // The FutureBuilder retains already acquired bytes while foreground
        // promotion retries underestimated speculative byte reservations.
        _page = widget.source.read(
          widget.manifest.key(widget.index),
          cancellation: _cancellation!,
        );
      }
    }
    if (oldWidget.source != widget.source ||
        oldWidget.manifest.key(oldWidget.index) !=
            widget.manifest.key(widget.index)) {
      _load();
    }
  }

  void _load() {
    _intent.reset();
    _intent.start();
    _presented = false;
    _placeholder = false;
    _hasFrame = false;
    if (widget.visible) {
      widget.prefetch?.foreground(widget.manifest.key(widget.index));
    }
    _cancellation?.cancel();
    final cancellation = CancellationController();
    _cancellation = cancellation;
    final warm = widget.prefetch?.memory.get(widget.manifest.key(widget.index));
    _page = warm != null
        ? SynchronousFuture(warm)
        : !widget.visible && widget.source is PrioritizedPageSource
        ? (widget.source as PrioritizedPageSource).readAhead(
            widget.manifest.key(widget.index),
            cancellation: cancellation,
            request: PageRequest(
              priority: PagePriority.lookahead,
              maximumBytes: widget.manifest.pages[widget.index].sizeBytes == 0
                  ? 32 * 1024 * 1024
                  : math.min(
                      32 * 1024 * 1024,
                      widget.manifest.pages[widget.index].sizeBytes * 5 ~/ 4 +
                          65536,
                    ),
            ),
          )
        : widget.source.read(
            widget.manifest.key(widget.index),
            cancellation: cancellation,
          );
  }

  Future<void> _retryInvalidImage() async {
    ReaderDecodedCache.invalidate(widget.manifest.key(widget.index));
    if (widget.source case final InvalidatablePageSource source) {
      try {
        await source.invalidate(widget.manifest.key(widget.index));
      } catch (_) {
        /* Retry remains available with an unavailable cache. */
      }
    }
    if (mounted) setState(_load);
  }

  /// Offscreen (cache-extent) pages keep no indeterminate animation ticking;
  /// the spinner appears once the page is visible.
  Widget get _loading => widget.visible
      ? Center(
          child: CircularProgressIndicator(
            semanticsLabel: context.tr("Loading page"),
          ),
        )
      : const SizedBox.expand();

  /// The zoomed decode is transient: evict it once the zoom step changes.
  ReaderImageKey? _zoomKey;
  void _releaseZoom() {
    final key = _zoomKey;
    _zoomKey = null;
    if (key != null) {
      // After the next frame, when the replacement image is already shown.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ReaderDecodedCache.evict(key),
      );
    }
  }

  @override
  void dispose() {
    ReaderTrace.sink?.call('unmount', widget.index, {'hasFrame': _hasFrame});
    _releaseZoom();
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final page = widget.manifest.pages[widget.index];
      final zoomed = widget.zoom > 1;
      final decode = readerDecodeSize(
        page,
        constraints.maxWidth *
            MediaQuery.devicePixelRatioOf(context) *
            widget.zoom,
        budgetBytes: zoomed ? zoomDecodeBudget : widget.decodeBudget,
        maximumWidth: zoomed ? 4096 : 2048,
      );
      return FutureBuilder<EncodedPage>(
        // Acquisition priority changes must keep the decoding Image mounted.
        // Account/revision/source changes still clear its old frame.
        key: ValueKey((widget.source, widget.manifest.key(widget.index))),
        future: _page,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            ReaderTrace.sink?.call('widget-error', widget.index, {
              'kind': error is ReaderFailure ? error.kind.name : 'unknown',
            });
            final text = error is ReaderFailure
                ? error.message
                : 'Unable to load this page.';
            if (error is ReaderFailure && error.kind == FailureKind.cancelled) {
              return const SizedBox.shrink();
            }
            return Center(
              child: ColoredBox(
                color: InkoraColors.of(context).scrim,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LText(
                          text,
                          style: TextStyle(
                            color: InkoraColors.of(context).onScrim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => setState(_load),
                          child: const LText('Retry page'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            _placeholder = true;
            return _loading;
          }
          ReaderTrace.sink?.call('widget-bytes', widget.index, {
            'bytes': snapshot.data!.bytes.length,
          });
          final provider = ReaderImageProvider(
            snapshot.data!,
            decode.width,
            decode.height,
            onDecoded: (duration) {
              widget.prefetch?.policy.network.observeDecode(duration);
              widget.telemetry?.decoded(duration);
            },
          );
          if (zoomed) _zoomKey = provider.imageKey;
          final quality =
              widget.imageQuality[RasterFormat.fromMediaType(
                snapshot.data!.mediaType,
              )] ??
              const RasterQuality();
          return Semantics(
            image: true,
            label: context.tr('Page {0}', [widget.index + 1]),
            child: Image(
              excludeFromSemantics: true,
              filterQuality: samplingQuality(quality.sampling),
              image: provider,
              key: ValueKey('page-image-${widget.index}'),
              frameBuilder: (context, child, frame, synchronous) {
                if (frame == null) {
                  if (_hasFrame) return child;
                  if (widget.visible) _placeholder = true;
                  return _loading;
                }
                if (!_hasFrame) {
                  ReaderTrace.sink?.call('widget-frame', widget.index, {
                    'synchronous': synchronous,
                  });
                }
                _hasFrame = true;
                if (widget.visible && !_presented) {
                  _presented = true;
                  final intent = _page;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && identical(intent, _page)) {
                      ReaderTrace.sink?.call(
                        'frame-callback',
                        widget.index,
                        {},
                      );
                      widget.telemetry?.presented(
                        widget.manifest.key(widget.index),
                        _intent.elapsed,
                        hadPlaceholder: _placeholder && !synchronous,
                      );
                    }
                  });
                }
                final raw = child as RawImage;
                final painted = quality.filter == VisualFilter.original
                    ? child
                    : ReaderFilteredImage(raw: raw, filter: quality.filter);
                final enhanced = EnhancedRawImage(
                  raw: raw,
                  fallback: painted,
                  colorFilter: visualColorFilter(quality.filter),
                );
                return ReaderTrace.sink == null
                    ? enhanced
                    : ReaderPaintProbe(
                        page: widget.index,
                        image: raw.image,
                        child: enhanced,
                      );
              },
              fit: widget.edgeToEdge || widget.fit == ReadingFit.width
                  ? BoxFit.fill
                  : BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Center(
                child: TextButton(
                  onPressed: _retryInvalidImage,
                  child: const LText('Invalid image — retry page'),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
