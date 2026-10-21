import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../icons/inkora_icons.dart';
import '../theme/inkora_motion.dart';
import '../theme/inkora_theme.dart';
import 'ink_surface.dart';
import 'inkora_widgets.dart';

/// The single header of a screen: an inset outlined bar with the native route
/// Back (when the route can pop), a title and optional actions.
///
/// Use it as `Scaffold.appBar`. It consumes the top safe area, so the body
/// below never needs its own status-bar padding. Detail pages with a cover
/// hero use [InkFloatingHeader] instead; Home uses [InkHomeHeader].
class InkScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const InkScreenHeader({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  /// Use `LText` for application copy and `Text` for server-owned names.
  final Widget title;
  final List<Widget>? actions;

  /// False hides the implied route Back (setup, wide settings panes).
  final bool automaticallyImplyLeading;

  /// Toolbar plus the vertical bar margins, excluding the top safe area.
  static const double extent = kToolbarHeight + 2 * InkSpace.sm;

  @override
  Size get preferredSize => const Size.fromHeight(extent);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpace.md,
        vertical: InkSpace.sm,
      ),
      child: InkOverlaySurface(
        child: AppBar(
          primary: false,
          title: title,
          actions: actions,
          automaticallyImplyLeading: automaticallyImplyLeading,
          // A settings root is first in its local Navigator, but still has
          // Home beneath its enclosing workspace route.
          leading:
              automaticallyImplyLeading &&
                  GoRouter.maybeOf(context)?.canPop() == true
              ? BackButton(onPressed: () => context.pop())
              : null,
          backgroundColor: Colors.transparent,
        ),
      ),
    ),
  );
}

/// Chooses which scroll view drives a header state.
typedef InkScrollPredicate = bool Function(ScrollMetrics metrics, int depth);

/// The page's outermost vertical scroll view (nested carousels are ignored).
bool primaryVerticalScroll(ScrollMetrics metrics, int depth) =>
    depth == 0 && metrics.axis == Axis.vertical;

/// Maps the offset of the primary vertical scroll view below [child] to a
/// value, notifying only when the mapped value changes. Scroll frames between
/// two thresholds therefore cost one comparison and never rebuild anything;
/// only the [builder] output (the header) rebuilds on a crossing.
class _ScrollThreshold<T> extends StatefulWidget {
  const _ScrollThreshold({
    required this.initial,
    required this.map,
    required this.builder,
    required this.layout,
    required this.child,
    this.accept = primaryVerticalScroll,
  });
  final T initial;
  final InkScrollPredicate accept;
  final T Function(double offset) map;
  final Widget Function(BuildContext context, T value) builder;

  /// Places the header (the [builder] output) relative to [child].
  final Widget Function(Widget header, Widget child) layout;
  final Widget child;

  @override
  State<_ScrollThreshold<T>> createState() => _ScrollThresholdState<T>();
}

class _ScrollThresholdState<T> extends State<_ScrollThreshold<T>> {
  late final _value = ValueNotifier<T>(widget.initial);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool _update(ScrollMetrics metrics, int depth) {
    if (widget.accept(metrics, depth)) {
      // ValueNotifier ignores equal values: only threshold crossings notify.
      _value.value = widget.map(metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.layout(
    ValueListenableBuilder<T>(
      valueListenable: _value,
      builder: (context, value, _) => widget.builder(context, value),
    ),
    NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics, n.depth),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _update(n.metrics, n.depth),
        child: widget.child,
      ),
    ),
  );
}

/// Home brand header. With [pinned], it reserves a fixed band for actions.
/// Otherwise it overlays the top of [child] and hides once the
/// scroll offset passes half its height, returning above that threshold. The
/// state flips only on crossings; there is no per-frame interpolation.
///
/// Without [pinned], [child] must start its content [InkScreenHeader.extent] below its top while
/// [enabled] (see `CatalogueScreen.topInset`). The top safe area is applied
/// here in both states so scrolling and resizing retain the child's position.
/// Phones and tablets share the same logo band.
class InkHomeHeader extends StatelessWidget {
  const InkHomeHeader({
    super.key,
    required this.child,
    this.enabled = true,
    this.pinned = false,
    this.actions,
  });
  final Widget child;
  final bool enabled;
  final bool pinned;
  final List<Widget>? actions;

  static const double threshold = InkScreenHeader.extent / 2;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    left: false,
    right: false,
    child: pinned && enabled
        ? Column(
            children: [
              SizedBox(
                key: const Key('home-header'),
                height: InkScreenHeader.extent,
                child: InkScreenHeader(
                  automaticallyImplyLeading: false,
                  title: const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: InkoraWordmark(),
                  ),
                  actions: actions,
                ),
              ),
              Expanded(child: child),
            ],
          )
        : _ScrollThreshold<bool>(
            initial: false,
            map: (offset) => offset > threshold,
            // The child keeps index 0 whether or not the header is enabled.
            layout: (header, child) =>
                Stack(fit: StackFit.expand, children: [child, header]),
            builder: (context, hidden) {
              if (!enabled) return const SizedBox.shrink();
              final reduced = MediaQuery.disableAnimationsOf(context);
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: hidden,
                  child: ExcludeSemantics(
                    excluding: hidden,
                    // The slide is a paint transform: clip it to the header slot so
                    // the hidden header never paints into the status bar area.
                    child: ClipRect(
                      child: AnimatedSlide(
                        key: const Key('home-header'),
                        offset: hidden ? const Offset(0, -1) : Offset.zero,
                        duration: reduced ? Duration.zero : InkoraMotion.tab,
                        curve: Curves.easeOutCubic,
                        child: SizedBox(
                          height: InkScreenHeader.extent,
                          child: InkScreenHeader(
                            automaticallyImplyLeading: false,
                            title: const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: InkoraWordmark(),
                            ),
                            actions: actions,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: child,
          ),
  );
}

/// A compact round control with a 48 dp target for floating header actions.
class InkHeaderBubble extends StatelessWidget {
  const InkHeaderBubble({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  static const double size = 48;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(InkoraLayout.controlHeight),
      tapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
    ),
    icon: Icon(icon, size: 22),
    onPressed: onPressed,
  );
}

/// The three states of [InkFloatingHeader]; they change only on crossings.
enum InkFloatingHeaderState {
  /// At rest: the bubbles float on the plain page background.
  rest,

  /// Scrolled: the band reads as a bar (divider below it).
  scrolled,

  /// Scrolled past the title threshold: the bar also shows the title.
  titled,
}

/// Floating variant of the screen header for detail pages with a hero: a round
/// Back bubble and optional trailing [actions] bubbles above [body].
///
/// The bubbles occupy a band of [contentInset] (safe area + bubble + margins)
/// above [body], so content starts below the bubbles at rest and is clipped
/// at the band while scrolling: it can never pass under a bubble, and
/// `ensureVisible`/accessibility focus never reveal content behind them. At
/// rest the band is the plain page background, so the bubbles float over the
/// page; once the primary (depth-0, vertical) scroll view in [body] scrolls,
/// the band becomes an opaque bar with a divider, and past [titleThreshold]
/// it also shows [title]. These states change only on threshold crossings.
///
/// Without [overlay], [body] needs no top safe-area padding (the band consumes
/// it), and [notificationPredicate] chooses the scroll view driving the band.
/// With [overlay], [body] fills the top inset for edge-to-edge artwork; it owns
/// safe-area clearance for its content while the Back bubble stays inset.
class InkFloatingHeader extends StatelessWidget {
  const InkFloatingHeader({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.titleThreshold = defaultTitleThreshold,
    this.overlay = false,
    this.onBack,
    this.notificationPredicate = primaryVerticalScroll,
  });

  final Widget body;
  final InkScrollPredicate notificationPredicate;

  /// Server-owned titles use `Text`, application copy `LText`.
  final Widget? title;

  /// Trailing [InkHeaderBubble]s.
  final List<Widget> actions;
  final double titleThreshold;
  final bool overlay;

  /// Defaults to popping the route, or Home when nothing can pop.
  final VoidCallback? onBack;

  static const double defaultTitleThreshold = 48;

  /// Bubble plus the margin above and below it, excluding the safe area.
  static const double barExtent = InkHeaderBubble.size + 2 * InkSpace.sm;

  /// Distance from the top of the screen to the first content of [body].
  static double contentInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + barExtent;

  @override
  Widget build(BuildContext context) {
    if (overlay) {
      return SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: body),
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + InkSpace.sm,
              start: InkSpace.lg,
              child: InkHeaderBubble(
                key: const Key('floating-header-back'),
                icon: InkIcons.caretLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed:
                    onBack ??
                    () => context.canPop() ? context.pop() : context.go('/'),
              ),
            ),
          ],
        ),
      );
    }
    return _ScrollThreshold<InkFloatingHeaderState>(
      initial: InkFloatingHeaderState.rest,
      accept: notificationPredicate,
      map: (offset) => offset <= 0
          ? InkFloatingHeaderState.rest
          : offset < titleThreshold
          ? InkFloatingHeaderState.scrolled
          : InkFloatingHeaderState.titled,
      layout: (header, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
      builder: (context, state) {
        final scheme = Theme.of(context).colorScheme;
        return DecoratedBox(
          key: ValueKey('floating-header-${state.name}'),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: state == InkFloatingHeaderState.rest
                ? null
                : Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpace.lg,
                vertical: InkSpace.sm,
              ),
              child: Row(
                children: [
                  InkHeaderBubble(
                    key: const Key('floating-header-back'),
                    icon: InkIcons.caretLeft,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed:
                        onBack ??
                        () =>
                            context.canPop() ? context.pop() : context.go('/'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: InkSpace.md,
                      ),
                      child: state == InkFloatingHeaderState.titled
                          ? DefaultTextStyle.merge(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                              child: KeyedSubtree(
                                key: const Key('floating-header-title'),
                                child: title ?? const SizedBox.shrink(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  for (final action in actions) ...[
                    const SizedBox(width: InkSpace.sm),
                    action,
                  ],
                ],
              ),
            ),
          ),
        );
      },
      child: body,
    );
  }
}
