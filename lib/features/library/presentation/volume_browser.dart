import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_filter_bar.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../offline/application/offline_coordinator.dart';
import '../../../offline/presentation/download_book_action.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue_filters.dart';
import '../domain/volume_progress.dart';
import 'book_cover.dart';
import 'catalogue_card.dart';
import 'progress_format.dart';
import 'series_header.dart';

/// Quick volume filters of the series page.
enum VolumeFilter { all, unread, inProgress, downloaded }

String volumeFilterLabel(VolumeFilter filter) => switch (filter) {
  VolumeFilter.all => 'All',
  VolumeFilter.unread => 'Unread',
  VolumeFilter.inProgress => 'In progress',
  VolumeFilter.downloaded => 'Downloaded',
};

/// Volumes matching [filter], in sequence order or reversed.
List<SeriesVolume> filterVolumes(
  SeriesProgress progress,
  VolumeFilter filter, {
  Set<String> downloaded = const {},
  bool descending = false,
}) {
  final result = [
    for (final volume in progress.volumes)
      if (switch (filter) {
        VolumeFilter.all => true,
        VolumeFilter.unread =>
          progress.of(volume.id).status == ReadingStatus.unread,
        VolumeFilter.inProgress => progress.of(volume.id).reading,
        VolumeFilter.downloaded => downloaded.contains('book:${volume.id}'),
      })
        volume,
  ];
  return descending ? result.reversed.toList(growable: false) : result;
}

/// View state of a volume list: filter, order, list/grid and selection.
/// Selection membership lives in [selection] so toggling one volume never
/// rebuilds the page, only the visible rows and the selection bar.
class VolumeBrowserController extends ChangeNotifier {
  VolumeFilter _filter = VolumeFilter.all;
  bool _descending = false, _grid = false, _selecting = false;
  final selection = ValueNotifier<Set<String>>(const {});

  VolumeFilter get filter => _filter;
  bool get descending => _descending;
  bool get grid => _grid;
  bool get selecting => _selecting;

  set filter(VolumeFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
  }

  void toggleOrder() {
    _descending = !_descending;
    notifyListeners();
  }

  void toggleView() {
    _grid = !_grid;
    notifyListeners();
  }

  void startSelection([Iterable<String> ids = const []]) {
    selection.value = {...ids};
    if (!_selecting) {
      _selecting = true;
      notifyListeners();
    }
  }

  void endSelection() {
    selection.value = const {};
    if (_selecting) {
      _selecting = false;
      notifyListeners();
    }
  }

  void toggle(String id) {
    final next = {...selection.value};
    if (!next.remove(id)) next.add(id);
    selection.value = next;
  }

  void selectAll(Iterable<String> ids) => selection.value = {...ids};

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}

/// Page-level volume operations. Created once per page so rows keep a stable
/// identity and the cached volume sliver stays valid. A null [markPrevious]
/// or [select] leaves that entry out of the row menu (downloaded volumes are
/// a subset of the series, so neither applies there).
final class VolumeActions {
  const VolumeActions({
    required this.open,
    required this.mark,
    this.markPrevious,
    this.select,
  });
  final void Function(SeriesVolume volume) open;
  final Future<void> Function(SeriesVolume volume, {required bool read}) mark;
  final Future<void> Function(SeriesVolume volume)? markPrevious;
  final void Function(SeriesVolume volume)? select;
}

/// The shared [InkFilterBar] with volume filter chips plus list/grid, order
/// and selection toggles. Chips scroll horizontally; the toggles stay visible.
class VolumeToolbar extends StatelessWidget {
  const VolumeToolbar({super.key, required this.controller});
  final VolumeBrowserController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => InkFilterBar(
      controlPrefix: 'volume',
      padding: const EdgeInsets.fromLTRB(
        InkSpace.lg,
        InkSpace.sm,
        InkSpace.sm,
        0,
      ),
      chips: [
        for (final filter in VolumeFilter.values)
          InkFilterChip(
            key: ValueKey('volume-filter-${filter.name}'),
            label: volumeFilterLabel(filter),
            icon: switch (filter) {
              VolumeFilter.all => InkIcons.books,
              VolumeFilter.unread => InkIcons.bookOpen,
              VolumeFilter.inProgress => InkIcons.circleHalf,
              VolumeFilter.downloaded => InkIcons.downloadSimple,
            },
            selected: controller.filter == filter,
            onSelected: () => controller.filter = filter,
          ),
      ],
      actions: [
        IconButton(
          key: const Key('volume-view'),
          tooltip: context.tr(controller.grid ? 'Show list' : 'Show grid'),
          onPressed: controller.toggleView,
          icon: Icon(controller.grid ? InkIcons.list : InkIcons.squaresFour),
        ),
        IconButton(
          key: const Key('volume-order'),
          tooltip: context.tr('Reverse order'),
          isSelected: controller.descending,
          onPressed: controller.toggleOrder,
          icon: const Icon(InkIcons.sortAscending),
          selectedIcon: const Icon(InkIcons.sortDescending),
        ),
        IconButton(
          key: const Key('volume-select'),
          tooltip: context.tr('Select volumes'),
          isSelected: controller.selecting,
          onPressed: controller.selecting
              ? controller.endSelection
              : controller.startSelection,
          icon: const Icon(InkIcons.checkSquare),
        ),
      ],
    ),
  );
}

/// Row/tile metrics derived from the theme and text scale.
typedef _Metrics = ({double row, double caption});

/// Lazy single-column volume rows or a cover grid. Rows have a
/// fixed extent, so [offsetOf] can position "jump to current volume" without
/// building intermediate rows.
class VolumeSliver extends StatefulWidget {
  const VolumeSliver({
    super.key,
    required this.seriesId,
    required this.volumes,
    required this.order,
    required this.grid,
    required this.selecting,
    required this.controller,
    required this.actions,
    this.currentId,
    this.seriesTitle = '',
  });
  final String seriesId;

  /// Removed from row titles that only repeat it with a number.
  final String seriesTitle;

  /// Volumes to show, already filtered and ordered.
  final List<SeriesVolume> volumes;

  /// Sequence index of every volume of the series (for Mark previous).
  final Map<String, int> order;
  final bool grid, selecting;
  final VolumeBrowserController controller;
  final VolumeActions actions;
  final String? currentId;

  @override
  State<VolumeSliver> createState() => VolumeSliverState();
}

class VolumeSliverState extends State<VolumeSliver> {
  /// SliverLayoutBuilder re-runs on every scroll frame (the scroll offset is
  /// part of its constraints); the produced sliver is cached per cross-axis
  /// extent and rebuilt only when inputs or inherited values change.
  ({double extent, int columns, double main, double spacing, Widget sliver})?
  _layout;
  _Metrics? _metrics;

  /// Scroll offset of [index]'s row from the start of this sliver.
  double? offsetOf(int index) {
    final layout = _layout;
    if (layout == null) return null;
    return (index ~/ layout.columns) * (layout.main + layout.spacing);
  }

  @override
  void didUpdateWidget(VolumeSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.grid != widget.grid ||
        old.selecting != widget.selecting ||
        old.currentId != widget.currentId ||
        old.seriesId != widget.seriesId ||
        old.seriesTitle != widget.seriesTitle ||
        !listEquals(old.volumes, widget.volumes) ||
        !mapEquals(old.order, widget.order)) {
      _layout = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layout = null;
    _metrics = null;
  }

  _Metrics _measure() {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
    );
    double height(TextStyle? style) {
      painter
        ..text = TextSpan(text: 'Ag', style: style)
        ..layout();
      return painter.height;
    }

    final title = height(volumeTitleStyle(theme));
    final meta = height(theme.textTheme.meta);
    painter.dispose();
    const cover = VolumeRow.coverWidth / InkoraLayout.coverRatio + 2;
    return (
      row:
          math.max(cover, title + meta + InkSpace.xs + 3) + 2 * InkSpace.sm + 1,
      caption: title + meta,
    );
  }

  Widget _build(double extent, _Metrics metrics) {
    final volumes = widget.volumes;
    if (widget.grid) {
      final columns = extent < 560
          ? 3
          : (extent / 175).floor().clamp(3, 6).toInt();
      final gap = extent < 560 ? 10.0 : 12.0;
      final width = (extent - gap * (columns - 1)) / columns;
      final main =
          width / InkoraLayout.coverRatio + InkSpace.xs + metrics.caption;
      return _cache(
        extent,
        columns,
        main,
        InkSpace.md,
        SliverGrid.builder(
          itemCount: volumes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: InkSpace.md,
            mainAxisExtent: main,
          ),
          itemBuilder: (_, index) => VolumeTile(
            key: ValueKey('volume-tile-${volumes[index].id}'),
            seriesId: widget.seriesId,
            seriesTitle: widget.seriesTitle,
            volume: volumes[index],
            index: widget.order[volumes[index].id] ?? 0,
            current: volumes[index].id == widget.currentId,
            selecting: widget.selecting,
            controller: widget.controller,
            actions: widget.actions,
          ),
        ),
      );
    }
    return _cache(
      extent,
      1,
      metrics.row,
      0,
      SliverGrid.builder(
        itemCount: volumes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisExtent: metrics.row,
        ),
        itemBuilder: (_, index) => VolumeRow(
          key: ValueKey('volume-${volumes[index].id}'),
          seriesId: widget.seriesId,
          seriesTitle: widget.seriesTitle,
          volume: volumes[index],
          index: widget.order[volumes[index].id] ?? 0,
          current: volumes[index].id == widget.currentId,
          selecting: widget.selecting,
          controller: widget.controller,
          actions: widget.actions,
        ),
      ),
    );
  }

  Widget _cache(
    double extent,
    int columns,
    double main,
    double spacing,
    Widget sliver,
  ) {
    _layout = (
      extent: extent,
      columns: columns,
      main: main,
      spacing: spacing,
      sliver: sliver,
    );
    return sliver;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics ??= _measure();
    return SliverLayoutBuilder(
      builder: (_, constraints) {
        final layout = _layout;
        if (layout != null && layout.extent == constraints.crossAxisExtent) {
          return layout.sliver;
        }
        return _build(constraints.crossAxisExtent, metrics);
      },
    );
  }
}

TextStyle? volumeTitleStyle(ThemeData theme) =>
    theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

/// Preserve the title supplied by the library; numbering is a fallback only.
String volumeRowTitle(
  AppStrings strings,
  SeriesVolume volume, {
  String seriesTitle = '',
}) => volumeName(strings, volume);

/// Status line of a volume: pages, reading state, offline and sync state.
String volumeStatusLine(
  AppStrings strings,
  SeriesVolume volume,
  VolumeProgress progress, {
  bool downloaded = false,
}) {
  if (!volume.available) return strings.text('Unavailable or removed');
  final state = switch (progress.status) {
    ReadingStatus.completed => strings.text('Read'),
    ReadingStatus.inProgress =>
      progress.ratio == null
          ? strings.text('In progress')
          : strings.text('{0} · {1}', [
              strings.text('In progress'),
              percentLabel(strings, progress.ratio!),
            ]),
    _ => strings.text('Unread'),
  };
  final parts = [
    if (!volume.isEbook && volume.pageCount > 0)
      strings.quantity(volume.pageCount, 'page'),
    state,
    if (downloaded) strings.text('Ready offline'),
    if (progress.conflict) strings.text('Sync conflict'),
  ];
  return parts.reduce((a, b) => strings.text('{0} · {1}', [a, b]));
}

typedef _MenuAction = ({String label, IconData icon, VoidCallback run});

List<_MenuAction> _menuActions(
  SeriesVolume volume,
  VolumeProgress progress,
  int index,
  VolumeActions actions,
) => [
  (
    label: 'Read book',
    icon: InkIcons.bookOpen,
    run: () => actions.open(volume),
  ),
  if (!progress.read)
    (
      label: 'Mark read',
      icon: InkIcons.check,
      run: () => actions.mark(volume, read: true),
    ),
  if (progress.status != ReadingStatus.unread)
    (
      label: 'Mark unread',
      icon: InkIcons.arrowCounterClockwise,
      run: () => actions.mark(volume, read: false),
    ),
  if (index > 0 && actions.markPrevious != null)
    (
      label: 'Mark previous volumes as read',
      icon: InkIcons.listChecks,
      run: () => actions.markPrevious!(volume),
    ),
  if (actions.select != null)
    (
      label: 'Select volumes',
      icon: InkIcons.checkSquare,
      run: () => actions.select!(volume),
    ),
];

Future<void> _showMenu(
  BuildContext context,
  List<_MenuAction> actions,
  Offset? position,
) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final box = context.findRenderObject() as RenderBox?;
  final anchor =
      position ??
      (box == null
          ? overlay.size.center(Offset.zero)
          : box.localToGlobal(box.size.center(Offset.zero)));
  final selected = await showMenu<_MenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      anchor & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      for (final action in actions)
        PopupMenuItem(
          value: action,
          child: Row(
            children: [
              Icon(action.icon, size: 20),
              const SizedBox(width: InkSpace.md),
              Flexible(child: LText(action.label)),
            ],
          ),
        ),
    ],
  );
  selected?.run();
}

/// Shared per-volume inputs: own progress and completed-download state are
/// selected individually, so other volumes' changes never rebuild it.
mixin _VolumeState on ConsumerWidget {
  String get seriesId;
  SeriesVolume get volume;

  VolumeProgress watchProgress(WidgetRef ref) => ref.watch(
    seriesProgressProvider(seriesId).select(
      (value) => value.asData?.value.of(volume.id) ?? VolumeProgress.unread,
    ),
  );

  bool watchDownloaded(WidgetRef ref) => ref.watch(
    downloadedIdentitiesProvider.select(
      (value) => value.asData?.value.contains('book:${volume.id}') ?? false,
    ),
  );
}

/// One list row: thumbnail, volume title, status line, a thin progress bar
/// while reading and the trailing download action. Tap opens (or toggles in
/// selection mode); long press opens the volume menu.
class VolumeRow extends ConsumerWidget with _VolumeState {
  static const coverWidth = 48.0;

  const VolumeRow({
    super.key,
    required this.seriesId,
    this.seriesTitle = '',
    required this.volume,
    required this.index,
    required this.current,
    required this.selecting,
    required this.controller,
    required this.actions,
    this.onRemoveDownload,
  });
  @override
  final String seriesId;
  final String seriesTitle;
  @override
  final SeriesVolume volume;
  final int index;
  final bool current, selecting;
  final VolumeBrowserController controller;
  final VolumeActions actions;

  /// Replaces the coordinator's removal (Downloads tests and owners).
  final Future<void> Function(String jobId)? onRemoveDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = watchProgress(ref);
    final downloaded = watchDownloaded(ref);
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final title = volumeRowTitle(strings, volume, seriesTitle: seriesTitle);
    final status = volumeStatusLine(
      strings,
      volume,
      progress,
      downloaded: downloaded,
    );
    final menu = volume.available
        ? _menuActions(volume, progress, index, actions)
        : const <_MenuAction>[];
    Offset? pressed;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .25)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: controller.selection,
              builder: (context, selection, _) {
                final selected = selection.contains(volume.id);
                return Semantics(
                  container: true,
                  button: true,
                  selected: selecting ? selected : null,
                  enabled: volume.available,
                  label: '$title, $status',
                  customSemanticsActions: selecting
                      ? null
                      : {
                          for (final action in menu.skip(1))
                            CustomSemanticsAction(
                              label: strings.text(action.label),
                            ): action.run,
                        },
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: !volume.available
                        ? null
                        : selecting
                        ? () => controller.toggle(volume.id)
                        : () => actions.open(volume),
                    onTapDown: (details) => pressed = details.globalPosition,
                    onLongPress: !volume.available
                        ? null
                        : selecting
                        ? () => controller.toggle(volume.id)
                        : () => _showMenu(context, menu, pressed),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: InkSpace.sm,
                      ),
                      child: Row(
                        children: [
                          if (selecting) ...[
                            Checkbox(
                              key: ValueKey('volume-check-${volume.id}'),
                              value: selected,
                              onChanged: volume.available
                                  ? (_) => controller.toggle(volume.id)
                                  : null,
                            ),
                            const SizedBox(width: InkSpace.xs),
                          ],
                          BookCover(
                            item: volume.item,
                            width: coverWidth,
                            muted: progress.read,
                          ),
                          const SizedBox(width: InkSpace.md),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: volumeTitleStyle(theme)?.copyWith(
                                    color: current
                                        ? theme.colorScheme.primary
                                        : progress.read
                                        ? theme.colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.meta?.copyWith(
                                    color: progress.conflict
                                        ? InkoraColors.of(context).danger
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (progress.reading &&
                                    progress.ratio != null) ...[
                                  const SizedBox(height: InkSpace.xs),
                                  LinearProgressIndicator(
                                    key: ValueKey(
                                      'volume-progress-${volume.id}',
                                    ),
                                    value: progress.ratio,
                                    minHeight: 3,
                                    borderRadius: InkRadius.small,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!selecting)
            DownloadBookAction(
              bookId: volume.id,
              title: volume.title,
              enabled: volume.available && volume.pageCount > 0,
              onRemoveDownload: onRemoveDownload,
            ),
        ],
      ),
    );
  }
}

/// Grid tile: cover with number/read/progress/offline badges, an accent
/// outline on the current volume and a selection mark in selection mode.
class VolumeTile extends ConsumerWidget with _VolumeState {
  const VolumeTile({
    super.key,
    required this.seriesId,
    this.seriesTitle = '',
    required this.volume,
    required this.index,
    required this.current,
    required this.selecting,
    required this.controller,
    required this.actions,
  });
  @override
  final String seriesId;
  final String seriesTitle;
  @override
  final SeriesVolume volume;
  final int index;
  final bool current, selecting;
  final VolumeBrowserController controller;
  final VolumeActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = watchProgress(ref);
    final downloaded = watchDownloaded(ref);
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = InkoraColors.of(context);
    final label = volumeName(strings, volume);
    final state = switch (progress.status) {
      ReadingStatus.completed => strings.text('Read'),
      ReadingStatus.inProgress =>
        progress.ratio == null
            ? strings.text('In progress')
            : strings.text('{0} · {1}', [
                strings.text('In progress'),
                percentLabel(strings, progress.ratio!),
              ]),
      _ => strings.text('Unread'),
    };
    final status = volumeStatusLine(
      strings,
      volume,
      progress,
      downloaded: downloaded,
    );
    final menu = volume.available
        ? _menuActions(volume, progress, index, actions)
        : const <_MenuAction>[];
    Offset? pressed;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: controller.selection,
      builder: (context, selection, _) {
        final selected = selection.contains(volume.id);
        return Semantics(
          container: true,
          button: true,
          selected: selecting ? selected : null,
          enabled: volume.available,
          label:
              '${volumeRowTitle(strings, volume, seriesTitle: seriesTitle)}, $status',
          customSemanticsActions: selecting
              ? null
              : {
                  for (final action in menu.skip(1))
                    CustomSemanticsAction(label: strings.text(action.label)):
                        action.run,
                },
          excludeSemantics: true,
          child: InkWell(
            borderRadius: InkRadius.small,
            onTap: !volume.available
                ? null
                : selecting
                ? () => controller.toggle(volume.id)
                : () => actions.open(volume),
            onTapDown: (details) => pressed = details.globalPosition,
            onLongPress: !volume.available
                ? null
                : selecting
                ? () => controller.toggle(volume.id)
                : () => _showMenu(context, menu, pressed),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: InkRadius.small,
                    border: current
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      BookCover(item: volume.item, muted: progress.read),
                      PositionedDirectional(
                        top: InkSpace.xs,
                        end: InkSpace.xs,
                        child: Column(
                          children: [
                            if (progress.read)
                              InkCoverIconBadge(
                                key: ValueKey('volume-read-${volume.id}'),
                                icon: InkIcons.check,
                                background: colors.success,
                                foreground: theme.colorScheme.surface,
                              ),
                            if (downloaded)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: InkSpace.xs,
                                ),
                                child: InkCoverIconBadge(
                                  key: ValueKey('volume-offline-${volume.id}'),
                                  icon: InkIcons.downloadSimple,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (progress.reading && progress.ratio != null)
                        Positioned(
                          left: InkSpace.sm,
                          right: InkSpace.sm,
                          bottom: InkSpace.sm,
                          child: LinearProgressIndicator(
                            value: progress.ratio,
                            minHeight: 4,
                            backgroundColor: colors.scrim,
                            borderRadius: InkRadius.small,
                          ),
                        ),
                      if (selecting)
                        Positioned.fill(
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : colors.scrim,
                                border: Border.all(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : colors.onScrim,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(InkSpace.xs),
                                child: Icon(
                                  InkIcons.check,
                                  key: ValueKey('volume-mark-${volume.id}'),
                                  size: 18,
                                  color: selected
                                      ? theme.colorScheme.onPrimary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpace.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: volumeTitleStyle(theme)?.copyWith(
                    color: current
                        ? theme.colorScheme.primary
                        : progress.read
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                Text(
                  state,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.meta?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Volumes list section: "jump to current volume", the lazy sliver and its
/// loading/empty/error states. Filtered membership is selected from the
/// series progress, so page saves that do not move a volume in or out of
/// the filter rebuild only the affected row.
class VolumeSection extends ConsumerWidget {
  const VolumeSection({
    super.key,
    required this.seriesId,
    required this.controller,
    required this.actions,
    required this.sliverKey,
    required this.onJump,
    this.seriesTitle = '',
  });
  final String seriesId;
  final String seriesTitle;
  final VolumeBrowserController controller;
  final VolumeActions actions;
  final GlobalKey<VolumeSliverState> sliverKey;
  final void Function(int index) onJump;

  static const jumpThreshold = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = controller.filter;
    final descending = controller.descending;
    final state = ref.watch(
      seriesProgressProvider(seriesId)
          .select((value) => value.whenData((progress) => progress.volumes)),
    );
    final downloaded = filter == VolumeFilter.downloaded
        ? ref.watch(
            downloadedIdentitiesProvider.select(
              (value) => value.asData?.value ?? const <String>{},
            ),
          )
        : const <String>{};
    final visible = ref.watch(
      seriesProgressProvider(seriesId).select(
        (value) => _Ids(
          value.asData == null
              ? const []
              : [
                  for (final volume in filterVolumes(
                    value.asData!.value,
                    filter,
                    downloaded: downloaded,
                    descending: descending,
                  ))
                    volume.id,
                ],
        ),
      ),
    );
    final resume = ref.watch(seriesResumeIdsProvider(seriesId));
    final currentId = ref.watch(
      seriesProgressProvider(seriesId).select(
        (value) => value.asData == null
            ? null
            : currentVolume(value.asData!.value, resume)?.id,
      ),
    );
    if (state.hasError) {
      return SliverToBoxAdapter(
        child: InkEmptyState(
          icon: InkIcons.warningCircle,
          title: 'Saved volumes unavailable',
          message: 'Unable to load this series’ saved volumes.',
          action: () => ref.invalidate(seriesVolumesProvider(seriesId)),
          label: 'Retry',
        ),
      );
    }
    final all = state.asData?.value;
    if (all == null) {
      return const SliverToBoxAdapter(child: InkSkeletonList());
    }
    if (all.isEmpty) {
      return const SliverToBoxAdapter(
        child: InkEmptyState(
          icon: InkIcons.bookOpen,
          title: 'No saved books in this series.',
        ),
      );
    }
    final byId = {for (final volume in all) volume.id: volume};
    final order = {for (var i = 0; i < all.length; i++) all[i].id: i};
    final volumes = [for (final id in visible.ids) byId[id]!];
    final jumpIndex = currentId == null ? -1 : visible.ids.indexOf(currentId);
    final strings = AppStrings.of(context);
    return SliverMainAxisGroup(
      slivers: [
        if (all.length > jumpThreshold && jumpIndex >= 0)
          SliverToBoxAdapter(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpace.sm),
                child: TextButton.icon(
                  key: const Key('volume-jump'),
                  onPressed: () => onJump(jumpIndex),
                  icon: const Icon(InkIcons.crosshairSimple, size: 18),
                  label: LText(
                    'Jump to current volume · {0}',
                    arguments: [volumeName(strings, byId[currentId]!)],
                  ),
                ),
              ),
            ),
          ),
        if (volumes.isEmpty)
          const SliverToBoxAdapter(
            child: InkEmptyState(
              icon: InkIcons.magnifyingGlassMinus,
              title: 'No volumes match this filter.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              InkSpace.lg,
              InkSpace.sm,
              InkSpace.lg,
              0,
            ),
            sliver: VolumeSliver(
              key: sliverKey,
              seriesId: seriesId,
              seriesTitle: seriesTitle,
              volumes: volumes,
              order: order,
              grid: controller.grid,
              selecting: controller.selecting,
              controller: controller,
              actions: actions,
              currentId: currentId,
            ),
          ),
      ],
    );
  }
}

/// Value-equal id list for `select`.
@immutable
final class _Ids {
  const _Ids(this.ids);
  final List<String> ids;
  @override
  bool operator ==(Object other) => other is _Ids && listEquals(other.ids, ids);
  @override
  int get hashCode => Object.hashAll(ids);
}

/// Bottom bar of selection mode: count, select all, mark read/unread and
/// download. Actions are enabled only when they would change a selected
/// volume.
class VolumeSelectionBar extends ConsumerWidget {
  const VolumeSelectionBar({
    super.key,
    required this.seriesId,
    required this.controller,
    required this.visibleIds,
    required this.onMark,
    required this.onDownload,
  });
  final String seriesId;
  final VolumeBrowserController controller;
  final List<String> Function() visibleIds;
  final void Function({required bool read}) onMark;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(seriesProgressProvider(seriesId)).asData?.value;
    final downloaded =
        ref.watch(downloadedIdentitiesProvider).asData?.value ??
        const <String>{};
    final strings = AppStrings.of(context);
    return Material(
      color: InkoraColors.of(context).raised,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpace.sm,
            InkSpace.xs,
            InkSpace.lg,
            InkSpace.md,
          ),
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: controller.selection,
            builder: (context, selection, _) {
              final selected = [
                for (final volume
                    in progress?.volumes ?? const <SeriesVolume>[])
                  if (selection.contains(volume.id) && volume.available) volume,
              ];
              final canRead = selected.any((v) => !progress!.of(v.id).read);
              final canUnread = selected.any(
                (v) => progress!.of(v.id).status != ReadingStatus.unread,
              );
              final canDownload = selected.any(
                (v) => v.pageCount > 0 && !downloaded.contains('book:${v.id}'),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('selection-close'),
                        tooltip: strings.text('Cancel'),
                        onPressed: controller.endSelection,
                        icon: const Icon(InkIcons.x),
                      ),
                      Expanded(
                        child: Text(
                          strings.text('Selected: {0}', [
                            strings.quantity(selection.length, 'volume'),
                          ]),
                          key: const Key('selection-count'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        key: const Key('selection-all'),
                        tooltip: strings.text('Select all'),
                        onPressed: () => controller.selectAll(visibleIds()),
                        icon: const Icon(InkIcons.selectionAll),
                      ),
                    ],
                  ),
                  _SelectionActions(
                    actions: [
                      OutlinedButton.icon(
                        key: const Key('selection-read'),
                        onPressed: canRead ? () => onMark(read: true) : null,
                        icon: const Icon(InkIcons.check, size: 18),
                        label: const LText('Mark read'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('selection-unread'),
                        onPressed: canUnread ? () => onMark(read: false) : null,
                        icon: const Icon(
                          InkIcons.arrowCounterClockwise,
                          size: 18,
                        ),
                        label: const LText('Mark unread'),
                      ),
                      FilledButton.icon(
                        key: const Key('selection-download'),
                        onPressed: canDownload ? onDownload : null,
                        icon: const Icon(InkIcons.downloadSimple, size: 18),
                        label: const LText('Download'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Selection actions: one row on wide windows; on compact windows the
/// secondary actions share a row and the last (primary) action spans the
/// width below, so no action is ever scrolled out of view. Large text sizes
/// stack full-width buttons (wrapping labels, at most 30 % of the window,
/// scrolling) so no label is clipped or wider than the screen.
class _SelectionActions extends StatelessWidget {
  const _SelectionActions({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (!large) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final secondary = actions.sublist(0, actions.length - 1);
          final row = Row(
            children: [
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(width: InkSpace.sm),
                Expanded(child: secondary[i]),
              ],
              if (wide) ...[
                const SizedBox(width: InkSpace.sm),
                Expanded(child: actions.last),
              ],
            ],
          );
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: InkSpace.sm),
            child: wide
                ? row
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row,
                      const SizedBox(height: InkSpace.xs),
                      actions.last,
                    ],
                  ),
          );
        },
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .3,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.only(start: InkSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: InkSpace.xs),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}
