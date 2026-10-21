import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_motion.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/widgets/route_visibility.dart';
import '../../../offline/application/offline_coordinator.dart';
import '../../../offline/data/download_store.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_filters.dart';
import '../domain/volume_progress.dart';
import 'catalogue_widgets.dart';
import 'series_header.dart';
import 'volume_actions.dart';
import 'volume_browser.dart';

/// Series details. Compact and medium windows: blurred hero,
/// reading action, then tabs About (first, default) and Volumes. Windows of
/// at least [paneBreakpoint] (the navigation-rail breakpoint): two panes
/// without tabs, About content scrolling on the left and volumes on the
/// right.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.id});
  final String id;

  static const paneBreakpoint = 840.0;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen>
    with TickerProviderStateMixin, RouteVisibilityMixin {
  final _scroll = ScrollController();
  final _volumesScroll = ScrollController();
  final _browser = VolumeBrowserController();
  final _sliverKey = GlobalKey<VolumeSliverState>();
  final _tabsKey = GlobalKey();
  final _volumeToolbarKey = GlobalKey();
  late TabController _tabs = _tabController(0, reduced: false);

  /// Reduced motion switches tabs without the indicator animation.
  TabController _tabController(int index, {required bool reduced}) =>
      TabController(
        length: 2,
        initialIndex: index,
        vsync: this,
        animationDuration: reduced ? Duration.zero : null,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if ((_tabs.animationDuration == Duration.zero) != reduced) {
      final previous = _tabs;
      _tabs = _tabController(previous.index, reduced: reduced);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  late final _actions = VolumeActions(
    open: (volume) => openCatalogueItem(context, volume.item),
    mark: (volume, {required read}) => _mark([volume], read: read),
    markPrevious: _markPrevious,
    select: (volume) => _browser.startSelection([volume.id]),
  );
  bool _selecting = false;

  String get _id => widget.id;

  @override
  void initState() {
    super.initState();
    _browser.addListener(_browserChanged);
    _observeVisibility();
  }

  /// While the reader (or another page) covers this page, its device
  /// progress watch pauses instead of re-reading per saved page.
  SeriesPageVisibility? _visibility;
  ProviderSubscription<SeriesPageVisibility>? _visibilityOwner;

  void _observeVisibility() {
    _visibilityOwner?.close();
    _visibilityOwner = ref.listenManual(seriesPageVisibilityProvider(_id), (
      _,
      next,
    ) {
      _visibility?.remove(this);
      _visibility = next..set(this, routeVisible);
    }, fireImmediately: true);
  }

  @override
  void routeVisibilityChanged(bool visible) => _visibility?.set(this, visible);

  @override
  void didUpdateWidget(SeriesDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _observeVisibility();
      _browser.endSelection();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (_volumesScroll.hasClients) _volumesScroll.jumpTo(0);
    }
  }

  /// Filter, order, view and selection mode changes are user actions; the
  /// whole page rebuilds for them (never for scrolling or page saves).
  void _browserChanged() {
    if (!mounted) return;
    // A notification from an earlier action would cover the selection bar.
    if (_browser.selecting && !_selecting) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }
    setState(() => _selecting = _browser.selecting);
  }

  @override
  void dispose() {
    _visibilityOwner?.close();
    _visibility?.remove(this);
    _browser.removeListener(_browserChanged);
    _browser.dispose();
    _tabs.dispose();
    _scroll.dispose();
    _volumesScroll.dispose();
    super.dispose();
  }

  SeriesProgress? get _progress =>
      ref.read(seriesProgressProvider(_id)).asData?.value;

  AppStrings get _strings => AppStrings.of(context);

  Future<void> _mark(List<SeriesVolume> volumes, {required bool read}) async {
    try {
      await markVolumes(ref, volumes, read: read);
      if (mounted) {
        notifyInk(
          context,
          'Reading status updated: {0}',
          arguments: [_strings.quantity(volumes.length, 'volume')],
        );
      }
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to save reading progress.');
    }
  }

  List<SeriesVolume> _selected() {
    final selection = _browser.selection.value;
    return [
      for (final volume in _progress?.volumes ?? const <SeriesVolume>[])
        if (selection.contains(volume.id) && volume.available) volume,
    ];
  }

  Future<void> _markSelection({required bool read}) async {
    final progress = _progress;
    if (progress == null) return;
    final targets = [
      for (final volume in _selected())
        if (read
            ? !progress.of(volume.id).read
            : progress.of(volume.id).status != ReadingStatus.unread)
          volume,
    ];
    if (targets.isEmpty) return;
    if (targets.length > 1 &&
        !await confirmInk(
          context,
          title: read ? 'Mark as read?' : 'Mark as unread?',
          message: read
              ? 'Selection: {0}. Reading progress is saved on this device and synchronized with Komga when connected.'
              : 'Selection: {0}. Their reading progress is reset on this device and on Komga.',
          messageArguments: [_strings.quantity(targets.length, 'volume')],
          confirmLabel: read ? 'Mark read' : 'Mark unread',
          destructive: !read,
        )) {
      return;
    }
    if (!mounted) return;
    _browser.endSelection();
    await _mark(targets, read: read);
  }

  Future<void> _markPrevious(SeriesVolume volume) async {
    final progress = _progress;
    if (progress == null) return;
    final index = progress.volumes.indexWhere((v) => v.id == volume.id);
    final targets = [
      for (final previous in progress.volumes.take(math.max(index, 0)))
        if (previous.available && !progress.of(previous.id).read) previous,
    ];
    if (targets.isEmpty) {
      notifyInk(
        context,
        'Reading status updated: {0}',
        arguments: [_strings.quantity(0, 'volume')],
      );
      return;
    }
    if (!await confirmInk(
      context,
      title: 'Mark previous volumes as read?',
      message: 'Unread volumes before this one: {0}. Reading progress is saved on this device and synchronized with Komga when connected.',
      messageArguments: [_strings.quantity(targets.length, 'volume')],
      confirmLabel: 'Mark read',
    )) {
      return;
    }
    await _mark(targets, read: true);
  }

  /// Book ids already downloaded or waiting in the download queue.
  Set<String> _downloadedOrQueued() => {
    for (final identity
        in ref.read(downloadedIdentitiesProvider).asData?.value ??
            const <String>{})
      if (identity.startsWith('book:')) identity.substring(5),
    for (final job
        in ref.read(downloadsProvider).asData?.value ?? const <DownloadJob>[])
      if (job.state != DownloadState.cancelled &&
          job.state != DownloadState.failed &&
          job.state != DownloadState.paused)
        job.bookId,
  };

  Future<void> _downloadSelection() async {
    final skip = _downloadedOrQueued();
    final targets = [
      for (final volume in _selected())
        if ((volume.isEbook || volume.pageCount > 0) &&
            !skip.contains(volume.id))
          volume.id,
    ];
    if (targets.isEmpty) return;
    if (targets.length > 1 &&
        !await confirmInk(
          context,
          title: 'Download volumes?',
          message:
              'Selection: {0}. The volumes are added to the download queue.',
          messageArguments: [_strings.quantity(targets.length, 'volume')],
          confirmLabel: 'Download',
        )) {
      return;
    }
    if (!mounted) return;
    _browser.endSelection();
    try {
      final result = await queueVolumeDownloads(ref, targets);
      if (mounted) {
        notifyInk(
          context,
          'Queued: {0} · Failed: {1}',
          arguments: [result.done, result.failed],
        );
      }
    } catch (_) {
      if (mounted) {
        notifyInk(
          context,
          'Unable to queue this download. Check connection and storage quota.',
        );
      }
    }
  }

  /// Confirm the complete series without entering selection mode.
  Future<void> _downloadSeries() async {
    final progress = _progress;
    if (progress == null) return;
    final skip = _downloadedOrQueued();
    final targets = [
      for (final volume in progress.volumes)
        if (volume.available &&
            (volume.isEbook || volume.pageCount > 0) &&
            !skip.contains(volume.id))
          volume.id,
    ];
    if (targets.isEmpty) return;
    if (!await confirmInk(
          context,
          title: 'Download volumes?',
          message:
              'Selection: {0}. The volumes are added to the download queue.',
          messageArguments: [_strings.quantity(targets.length, 'book')],
          confirmLabel: 'Download',
        ) ||
        !mounted) {
      return;
    }
    try {
      final result = await queueVolumeDownloads(ref, targets);
      if (mounted) {
        notifyInk(
          context,
          'Queued: {0} · Failed: {1}',
          arguments: [result.done, result.failed],
        );
      }
    } catch (_) {
      if (mounted) {
        notifyInk(
          context,
          'Unable to queue this download. Check connection and storage quota.',
        );
      }
    }
  }

  Future<void> _markSeries() async {
    final read = await showInkSheet<bool>(
      context: context,
      title: 'Reading progress',
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(InkIcons.check),
              title: const LText('Mark read'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: const Icon(InkIcons.arrowCounterClockwise),
              title: const LText('Mark unread'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      ),
    );
    if (read == null || !mounted) return;
    final progress = _progress;
    if (progress == null) return;
    final targets = [
      for (final volume in progress.volumes)
        if (volume.available &&
            (read
                ? !progress.of(volume.id).read
                : progress.of(volume.id).status != ReadingStatus.unread))
          volume,
    ];
    if (targets.isEmpty) return;
    if (!await confirmInk(
          context,
          title: read ? 'Mark as read?' : 'Mark as unread?',
          message: read
              ? 'Selection: {0}. Reading progress is saved on this device and synchronized with Komga when connected.'
              : 'Selection: {0}. Their reading progress is reset on this device and on Komga.',
          messageArguments: [_strings.quantity(targets.length, 'book')],
          confirmLabel: read ? 'Mark read' : 'Mark unread',
          destructive: !read,
        ) ||
        !mounted) {
      return;
    }
    await _mark(targets, read: read);
  }

  List<String> _visibleIds() {
    final progress = _progress;
    if (progress == null) return const [];
    final downloaded =
        ref.read(downloadedIdentitiesProvider).asData?.value ??
        const <String>{};
    return [
      for (final volume in filterVolumes(
        progress,
        _browser.filter,
        downloaded: downloaded,
      ))
        if (volume.available) volume.id,
    ];
  }

  /// Keeps the tab bar where it is: switching tabs from a scrolled position
  /// shows the new tab's start right below the pinned bar.
  void _selectTab(int index) {
    final render = _tabsKey.currentContext?.findRenderObject();
    final sliver = render == null
        ? null
        : render is RenderSliver
        ? render
        : _ancestorSliver(render);
    setState(() => _tabs.index = index);
    if (sliver != null && _scroll.hasClients) {
      final start = sliver.constraints.precedingScrollExtent;
      if (_scroll.offset > start) _scroll.jumpTo(start);
    }
  }

  static RenderSliver? _ancestorSliver(RenderObject render) {
    RenderObject? node = render;
    while (node != null && node is! RenderSliver) {
      node = node.parent;
    }
    return node as RenderSliver?;
  }

  /// Scrolls the volume list to [index] (filtered order) below any pinned
  /// header. Rows have fixed extents, so no intermediate row is built.
  void _jump(int index, {required bool wide}) {
    final offset = _sliverKey.currentState?.offsetOf(index);
    final render = _sliverKey.currentContext?.findRenderObject();
    final controller = wide ? _volumesScroll : _scroll;
    if (offset == null || render is! RenderSliver || !controller.hasClients) {
      return;
    }
    final toolbar = _volumeToolbarKey.currentContext?.findRenderObject();
    final pinned = wide
        ? (toolbar is RenderBox && toolbar.hasSize ? toolbar.size.height : 0.0)
        : _pinnedExtent(context);
    final target =
        (render.constraints.precedingScrollExtent +
                offset -
                pinned -
                InkSpace.sm)
            .clamp(0.0, controller.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(target);
    } else {
      controller.animateTo(
        target,
        duration: InkoraMotion.forward,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Height of the compact pinned tab bar at the current text scale;
  /// large text gets room for two-line tab labels.
  static double _pinnedExtent(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return scale > 1.3 ? 40 * scale + 16 : math.max(48.0, 20 * scale + 28);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(catalogueItemProvider((CatalogueKind.series, _id)));
    final volumeCount = ref.watch(
      seriesVolumesProvider(_id).select((value) => value.asData?.value.length),
    );
    final wide =
        MediaQuery.sizeOf(context).width >= SeriesDetailScreen.paneBreakpoint;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _browser.endSelection();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (!wide && data.asData?.value != null)
              Positioned.fill(child: SeriesBackdrop(item: data.asData!.value!)),
            InkFloatingHeader(
              overlay: wide,
              transparentAtRest: !wide,
              title: data.asData?.value == null
                  ? null
                  : Text(data.asData!.value!.title),
              body: SafeArea(
                top: false,
                bottom: false,
                child: data.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => InkEmptyState(
                    icon: InkIcons.warningCircle,
                    title: 'Details unavailable',
                    message: 'Unable to open saved details.',
                    action: () => ref.invalidate(
                      catalogueItemProvider((CatalogueKind.series, _id)),
                    ),
                    label: 'Retry',
                  ),
                  data: (item) {
                    if (item == null) {
                      return const InkEmptyState(
                        icon: InkIcons.bookOpen,
                        title: 'Item unavailable',
                        message: 'This item is not in the saved catalogue.',
                      );
                    }
                    final count = volumeCount ?? item.itemCount;
                    return wide
                        ? _panes(context, item, count)
                        : _single(context, item, count);
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _selecting
            ? VolumeSelectionBar(
                key: const Key('selection-bar'),
                seriesId: _id,
                controller: _browser,
                visibleIds: _visibleIds,
                onMark: _markSelection,
                onDownload: _downloadSelection,
              )
            : null,
      ),
    );
  }

  Widget _readingBlock(CatalogueItem item) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: InkSpace.lg),
    child: item.canOpen
        ? SeriesReadAction(
            seriesId: _id,
            onDownload: _downloadSeries,
            onMark: _markSeries,
          )
        : const LText('Unavailable or removed. Saved metadata is retained.'),
  );

  List<Widget> _volumeSlivers(CatalogueItem item, {required bool wide}) => [
    if (wide)
      PinnedHeaderSliver(
        child: ColoredBox(
          key: _volumeToolbarKey,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: VolumeToolbar(controller: _browser),
        ),
      )
    else
      SliverToBoxAdapter(child: VolumeToolbar(controller: _browser)),
    VolumeSection(
      seriesId: _id,
      seriesTitle: item.title,
      controller: _browser,
      actions: _actions,
      sliverKey: _sliverKey,
      onJump: (index) => _jump(index, wide: wide),
    ),
  ];

  Widget _single(BuildContext context, CatalogueItem item, int count) {
    final extent = _pinnedExtent(context);
    final bottom = MediaQuery.paddingOf(context).bottom + InkSpace.xl;
    return InkContent(
      child: CustomScrollView(
        key: ValueKey('series-$_id'),
        controller: _scroll,
        scrollCacheExtent: const ScrollCacheExtent.viewport(1),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CatalogueRefreshStatus(),
                SeriesHero(item: item, volumeCount: count, showBackdrop: false),
                _readingBlock(item),
                const SizedBox(height: InkSpace.lg),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedDelegate(
              extent: extent,
              child: _TabStrip(
                key: _tabsKey,
                controller: _tabs,
                volumes: count,
                onTap: _selectTab,
                // TabBar adds its indicator weight below the tabs.
                height: extent - 2,
              ),
            ),
          ),
          for (final sliver in <Widget>[
            if (_tabs.index == 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  InkSpace.lg,
                  InkSpace.lg,
                  InkSpace.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  key: const Key('series-about'),
                  child: SeriesAbout(item: item),
                ),
              )
            else if (item.canOpen)
              ..._volumeSlivers(item, wide: false),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SizedBox(height: bottom),
            ),
          ])
            DecoratedSliver(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              sliver: sliver,
            ),
        ],
      ),
    );
  }

  Widget _panes(BuildContext context, CatalogueItem item, int count) {
    final width = MediaQuery.sizeOf(context).width;
    final left = (width * .36).clamp(320.0, 440.0);
    final bottom = MediaQuery.paddingOf(context).bottom + InkSpace.xl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: left,
          child: CustomScrollView(
            key: const Key('series-about-pane'),
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CatalogueRefreshStatus(),
                    SeriesHero(
                      item: item,
                      volumeCount: count,
                      coverWidth: 120,
                      topInset: InkFloatingHeader.contentInset(context),
                    ),
                    _readingBlock(item),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(InkSpace.lg),
                sliver: SliverToBoxAdapter(
                  key: const Key('series-about'),
                  child: SeriesAbout(item: item),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          ),
        ),
        const VerticalDivider(key: Key('series-pane-divider'), width: 1),
        Expanded(
          // The left pane drives the floating header (title and bar state);
          // the volume pane's scroll notifications stop here.
          child: SafeArea(
            bottom: false,
            child: _ScrollIsolation(
              child: CustomScrollView(
                key: const Key('series-volumes-pane'),
                controller: _volumesScroll,
                scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                slivers: [
                  if (item.canOpen) ..._volumeSlivers(item, wide: true),
                  SliverToBoxAdapter(child: SizedBox(height: bottom)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollIsolation extends StatelessWidget {
  const _ScrollIsolation({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) => true,
          child: child,
        ),
      );
}

class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  _PinnedDelegate({required this.extent, required this.child});
  final double extent;
  final Widget child;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      child;
  @override
  bool shouldRebuild(_PinnedDelegate old) =>
      old.extent != extent || old.child != child;
}

/// About (first, default) and Volumes tabs on the page background.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    super.key,
    required this.controller,
    required this.volumes,
    required this.onTap,
    required this.height,
  });
  final TabController controller;
  final int volumes;
  final double height;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Align(
      alignment: AlignmentDirectional.bottomStart,
      // Fixed tabs keep both labels on screen at any text size; long labels
      // wrap to a second line instead of scrolling out of view.
      child: TabBar(
        key: const Key('series-tabs'),
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: InkSpace.sm),
        onTap: onTap,
        tabs: [
          for (final (key, label) in [
            ('series-tab-about', context.tr('About')),
            ('series-tab-volumes', context.tr('Volumes ({0})', [volumes])),
          ])
            Tab(
              key: Key(key),
              height: height,
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
  );
}
