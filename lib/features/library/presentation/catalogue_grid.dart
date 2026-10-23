import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/inkora_theme.dart';
import '../../../reader/domain/page_source.dart';
import '../application/cover_providers.dart';
import '../data/cover_repository.dart';
import '../domain/catalogue.dart';
import 'book_cover.dart';
import 'catalogue_card.dart';

/// Shared geometry and bounded artwork readiness for catalogue/download grids.
class CatalogueGrid extends ConsumerStatefulWidget {
  const CatalogueGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns,
    this.artwork,
    this.topPadding = 16,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int? columns;
  final List<CatalogueItem>? artwork;
  final double topPadding;
  @override
  ConsumerState<CatalogueGrid> createState() => _CatalogueGridState();
}

class _CatalogueGridState extends ConsumerState<CatalogueGrid> {
  final _jobs = <CoverKey, CancellationController>{};
  final _decodeQueue = <CoverKey>[];
  int _decoding = 0;
  bool _scheduled = false;
  ({int first, int end, double width, CoverRepository repository})? _plan,
      _applied;
  CoverRepository? _repository;
  double _decodeWidth = 0;

  void _clear() {
    for (final signal in _jobs.values) {
      signal.cancel();
    }
    _jobs.clear();
    _decodeQueue.clear();
    _applied = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _schedule(int first, int end, double width, CoverRepository repository) {
    final plan = (first: first, end: end, width: width, repository: repository);
    // Scroll frames inside the same row window need no new planning pass.
    if (plan == _plan && plan == _applied) return;
    _plan = plan;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final plan = _plan;
      if (plan == null) return;
      _applied = plan;
      if (_repository != plan.repository || _decodeWidth != plan.width) {
        _clear();
      }
      _repository = plan.repository;
      _decodeWidth = plan.width;
      final desired = <CoverKey>{
        for (final item
            in (widget.artwork ?? const <CatalogueItem>[])
                .skip(plan.first)
                .take(plan.end - plan.first))
          if (item.canOpen &&
              (item.kind == CatalogueKind.book ||
                  item.kind == CatalogueKind.series))
            (kind: item.kind.name, id: item.id, modified: item.modified),
      };
      for (final key
          in _jobs.keys.where((key) => !desired.contains(key)).toList()) {
        _jobs.remove(key)?.cancel();
        _decodeQueue.remove(key);
      }
      for (final key in desired) {
        if (_jobs.containsKey(key)) continue;
        final signal = CancellationController();
        _jobs[key] = signal;
        unawaited(_prepare(key, signal, plan.repository));
      }
    });
  }

  Future<void> _prepare(
    CoverKey key,
    CancellationController signal,
    CoverRepository repository,
  ) async {
    await repository.load(key, signal, speculative: true);
    if (!mounted || signal.isCancelled || _repository != repository) return;
    // Queue keys, not byte objects: the encoded LRU retains ownership/bounds.
    _decodeQueue.add(key);
    _drain();
  }

  void _drain() {
    while (_decoding < 2 && _decodeQueue.isNotEmpty && mounted) {
      final key = _decodeQueue.removeAt(0);
      final bytes = _repository?.peek(key);
      if (bytes == null || _jobs[key]?.isCancelled != false) continue;
      _decoding++;
      final image = coverImage(
        _repository!,
        key,
        bytes,
        _decodeWidth,
        MediaQuery.devicePixelRatioOf(context),
      );
      unawaited(
        precacheImage(
          image,
          context,
          onError: (Object _, StackTrace? _) {},
        ).whenComplete(() {
          _decoding--;
          if (mounted) _drain();
        }),
      );
    }
  }

  /// Geometry/sliver reused while the cross-axis extent is unchanged.
  /// SliverLayoutBuilder re-runs on every scroll frame (scroll offset is part
  /// of SliverConstraints); returning the identical sliver widget prevents the
  /// grid delegate from rebuilding every visible card each frame.
  ({double extent, double width, double height, int columns, Widget sliver})?
  _layout;

  ({double extent, double width, double height, int columns, Widget sliver})
  _measure(double extent) {
    final columns = catalogueColumnCount(extent, columns: widget.columns);
    final gap = extent < 600 ? 10.0 : 12.0;
    final width = catalogueCoverWidth(extent, columns: columns);
    // Inherited lookups use this State's context so theme/text-scale changes
    // rebuild the State and invalidate the cached geometry.
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter
      ..text = TextSpan(text: 'Ag', style: catalogueTitleStyle(context, width))
      ..layout();
    final titleHeight = painter.height;
    painter
      ..text = TextSpan(
        text: 'Ag',
        style: Theme.of(context).textTheme.bodySmall,
      )
      ..layout();
    final height =
        width / InkoraLayout.coverRatio + 4 + titleHeight * 2 + painter.height;
    painter.dispose();
    return (
      extent: extent,
      width: width,
      height: height,
      columns: columns,
      sliver: SliverPadding(
        padding: EdgeInsets.fromLTRB(16, widget.topPadding, 16, 16),
        sliver: SliverGrid.builder(
          itemCount: widget.itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: gap,
            mainAxisExtent: height,
          ),
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.artwork == null
        ? null
        : ref.watch(coverRepositoryProvider).asData?.value;
    final enabled = TickerMode.valuesOf(context).enabled;
    // Any State rebuild (new items/builder, theme, text scale) re-measures.
    _layout = null;
    MediaQuery.textScalerOf(context);
    Theme.of(context);
    return SliverLayoutBuilder(
      builder: (_, constraints) {
        var layout = _layout;
        if (layout == null || layout.extent != constraints.crossAxisExtent) {
          layout = _layout = _measure(constraints.crossAxisExtent);
        }
        final (:height, :columns, :width, extent: _, sliver: _) = layout;
        if (repository != null && enabled) {
          final row = (constraints.scrollOffset / (height + 12)).floor();
          final visibleRows = math.max(
            1,
            (constraints.remainingPaintExtent / (height + 12)).ceil(),
          );
          final backwards =
              constraints.userScrollDirection == ScrollDirection.forward;
          final first =
              math.max(0, row - (backwards ? visibleRows * 2 : 1)) * columns;
          final end = math.min(
            widget.itemCount,
            math.min(
              first + 48,
              (row + visibleRows * (backwards ? 1 : 3) + 1) * columns,
            ),
          );
          _schedule(first.clamp(0, widget.itemCount), end, width, repository);
        }
        return layout.sliver;
      },
    );
  }
}
