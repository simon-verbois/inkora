import '../../app/l10n/app_strings.dart';
import '../icons/inkora_icons.dart';

import 'package:flutter/material.dart';

import '../theme/inkora_theme.dart';
import 'ink_surface.dart';
import '../theme/inkora_motion.dart';

class InkoraWordmark extends StatelessWidget {
  const InkoraWordmark({super.key, this.size = 29});
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    'Inkora',
    style: TextStyle(
      fontFamily: 'LibreBaskerville',
      fontWeight: FontWeight.w700,
      fontSize: size,
      letterSpacing: -.8,
      color: Theme.of(context).brightness == Brightness.light
          ? InkoraTheme.lightBrand
          : Theme.of(context).colorScheme.primary,
    ),
  );
}

class InkPanel extends StatelessWidget {
  const InkPanel({
    super.key,
    this.title,
    this.icon,
    this.action,
    required this.child,
    this.framed = true,
    this.padding,
  });
  final String? title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final bool framed;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final colors = InkoraColors.of(context);
    final contentPadding =
        padding ?? (framed ? const EdgeInsets.all(12) : EdgeInsets.zero);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: framed ? 12 : 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: LText(
                          title!,
                          style: Theme.of(context).textTheme.sectionTitle
                              ?.copyWith(color: colors.heading),
                        ),
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: title == null
              ? contentPadding
              : contentPadding
                    .resolve(Directionality.of(context))
                    .copyWith(top: 0),
          child: child,
        ),
      ],
    );
    return framed ? InkSurface(child: content) : content;
  }
}

class InkContent extends StatelessWidget {
  const InkContent({
    super.key,
    required this.child,
    this.maxWidth = InkoraLayout.maxContentWidth,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Empty, error and unavailable states. [title], [message] and [label] are
/// source messages: this widget translates them, so callers must not pass
/// already translated text.
class InkEmptyState extends StatelessWidget {
  const InkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.label,
  });
  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? action;
  final String? label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: InkSpace.xl,
      horizontal: InkSpace.md,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: InkSpace.md),
        Semantics(
          header: true,
          child: LText(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.sectionTitle,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: InkSpace.sm),
          LText(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.body?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (action != null && label != null) ...[
          const SizedBox(height: InkSpace.md),
          FilledButton(onPressed: action, child: LText(label!)),
        ],
      ],
    ),
  );
}

class InkSettingsRow extends StatelessWidget {
  const InkSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.value,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Current value shown before the chevron (already localized), for
  /// example the theme name or gesture preset.
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.sectionTitle),
      subtitle: subtitle == null ? null : LText(subtitle!),
      onTap: onTap,
      trailing:
          trailing ??
          (value == null
              ? const Icon(InkIcons.caretRight)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.meta,
                        ),
                      ),
                      const SizedBox(width: InkSpace.xs),
                      const Icon(InkIcons.caretRight),
                    ],
                  ),
                )),
    ),
  );
}

/// The single bottom-sheet presentation: a floating panel with an optional
/// [title] row (plus a secondary [action]), a body that scrolls when
/// [scrollable] is set and an optional fixed [footer] action bar. The height
/// follows the content, or [heightFactor] of the screen when given (needed by
/// bodies that use Expanded lists). Only the native handle accepts dismissal
/// drags; body gestures and barrier taps stay inside the sheet. Back and explicit
/// content actions retain their existing route ownership.
Future<T?> showInkSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? action,
  Widget? footer,
  bool scrollable = false,
  double? heightFactor,
}) => showModalBottomSheet<T>(
  context: context,
  sheetAnimationStyle: InkoraMotion.sheetStyle(context),
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  showDragHandle: false,
  enableDrag: false,
  isDismissible: false,
  constraints: const BoxConstraints(maxWidth: 784),
  builder: (_) => Builder(
    builder: (context) {
      // Reuse the route's controller and drag callbacks, including its linear
      // finger tracking and settling curve. The inner native sheet puts its
      // handle INSIDE our inset surface, without enabling drags on the body.
      final routeSheet = context.findAncestorWidgetOfExactType<BottomSheet>()!;
      final maxHeight = MediaQuery.sizeOf(context).height * .85;
      Widget body = scrollable ? SingleChildScrollView(child: child) : child;
      if (title != null || footer != null) {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) InkSheetHeader(title: title, action: action),
            Flexible(child: body),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  InkSpace.lg,
                  InkSpace.sm,
                  InkSpace.lg,
                  InkSpace.lg,
                ),
                child: footer,
              ),
          ],
        );
      }
      final framedBody = Listener(
        onPointerCancel: (_) {
          final controller = routeSheet.animationController;
          if (controller != null &&
              controller.value < 1 &&
              controller.status != AnimationStatus.reverse &&
              ModalRoute.of(context)?.isCurrent == true) {
            routeSheet.onDragEnd?.call(DragEndDetails(), isClosing: false);
            controller.forward();
          }
        },
        child: BottomSheet(
          animationController: routeSheet.animationController,
          onClosing: routeSheet.onClosing,
          onDragStart: routeSheet.onDragStart,
          onDragEnd: routeSheet.onDragEnd,
          enableDrag: false,
          showDragHandle: true,
          dragHandleSize: const Size(36, 4),
          dragHandleColor: Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: .5),
          backgroundColor: Colors.transparent,
          elevation: 0,
          builder: (_) => body,
        ),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(
          InkSpace.md,
          InkSpace.sm,
          InkSpace.md,
          InkSpace.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: InkOverlaySurface(
            child: heightFactor == null
                ? framedBody
                : SizedBox(
                    height: (MediaQuery.sizeOf(context).height * heightFactor)
                        .clamp(0, maxHeight),
                    child: framedBody,
                  ),
          ),
        ),
      );
    },
  ),
);

/// Centered choices outside the reader. Keeps the same shared panel content,
/// bounded height and root Navigator ownership as reader sheets.
Future<T?> showInkPopup<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? action,
  Widget? footer,
  bool scrollable = false,
  double? heightFactor,
}) => showDialog<T>(
  context: context,
  builder: (context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SizedBox(
        height: heightFactor == null
            ? null
            : MediaQuery.sizeOf(context).height * heightFactor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) InkSheetHeader(title: title, action: action),
            Flexible(
              child: scrollable ? SingleChildScrollView(child: child) : child,
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.all(InkSpace.lg),
                child: footer,
              ),
          ],
        ),
      ),
    ),
  ),
);

/// Title row shared by sheets: localized [title] and an optional trailing
/// secondary [action] (for example Reset or Add).
class InkSheetHeader extends StatelessWidget {
  const InkSheetHeader({super.key, required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      InkSpace.lg,
      InkSpace.md,
      InkSpace.sm,
      InkSpace.sm,
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: InkoraLayout.touchTarget),
      // The action may take at most half the row (long localized labels at
      // large text wrap instead of overflowing).
      child: LayoutBuilder(
        builder: (context, bounds) => Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: LText(
                  title,
                  style: Theme.of(context).textTheme.sheetTitle,
                ),
              ),
            ),
            if (action != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bounds.maxWidth / 2),
                child: action,
              ),
          ],
        ),
      ),
    ),
  );
}

/// The single dialog presentation. [title] is a source message; [content]
/// and [actions] are built by the caller (input dialogs) or by [confirmInk].
class InkDialog extends StatelessWidget {
  const InkDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = false,
    this.contentPadding,
  });
  final String title;
  final Widget content;
  final List<Widget> actions;

  /// Scroll title, message and actions together (long confirmations at
  /// large text sizes on small windows).
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: scrollable,
    title: LText(title, style: Theme.of(context).textTheme.sheetTitle),
    content: content,
    contentPadding: contentPadding,
    actions: actions,
  );
}

/// Asks the user to confirm an action. Returns true only for an explicit
/// confirmation; dismissing or cancelling returns false. [destructive] paints
/// the confirm button with the danger color. [details] adds content below the
/// message (for example a summary of what is affected).
Future<bool> confirmInk(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  List<Object?> messageArguments = const [],
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Widget? details,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = InkoraColors.of(context);
      final text = LText(message, arguments: messageArguments);
      return InkDialog(
        scrollable: true,
        title: title,
        content: details == null
            ? text
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  const SizedBox(height: InkSpace.md),
                  details,
                ],
              ),
        actions: [
          TextButton(
            key: const Key('ink-confirm-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: LText(cancelLabel),
          ),
          FilledButton(
            key: const Key('ink-confirm-accept'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: LText(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Keeps floating notifications inside the current window, including resize.
class InkNotificationTheme extends StatelessWidget {
  const InkNotificationTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SnackBarTheme(
    data: SnackBarTheme.of(context).copyWith(
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 480.0),
    ),
    child: child,
  );
}

/// Shows only the latest localized notification, without an accumulating queue.
/// Action messages allow more reading time and remain available to screen readers.
/// Does nothing without a messenger.
void notifyInk(
  BuildContext context,
  String message, {
  List<Object?> arguments = const [],
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final hasAction = actionLabel != null && onAction != null;
  final accessible = MediaQuery.accessibleNavigationOf(context);
  var actionTriggered = false;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: Duration(seconds: accessible ? 10 : (hasAction ? 6 : 2)),
      persist: accessible && hasAction,
      content: !hasAction
          ? LText(message, arguments: arguments)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LText(message, arguments: arguments),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  // Let long translated actions wrap at large text sizes.
                  child: TextButton(
                    onPressed: () {
                      if (actionTriggered) return;
                      actionTriggered = true;
                      messenger.hideCurrentSnackBar(
                        reason: SnackBarClosedReason.action,
                      );
                      onAction();
                    },
                    child: LText(actionLabel),
                  ),
                ),
              ],
            ),
    ),
  );
}

/// Static loading placeholder. It never animates, so it costs nothing while
/// offscreen or idle (PERFORMANCE_GUIDELINES: no perpetual spinners).
class InkSkeleton extends StatelessWidget {
  const InkSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = InkRadius.small,
  });
  final double? width, height;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: InkoraColors.of(context).raised,
        borderRadius: borderRadius,
      ),
    ),
  );
}

/// List-shaped first-load placeholder: [rows] static rows with a leading
/// block and two text lines. Announced once as loading to screen readers.
class InkSkeletonList extends StatelessWidget {
  const InkSkeletonList({super.key, this.rows = 6, this.leading = true});
  final int rows;
  final bool leading;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('Loading'),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.all(InkSpace.lg),
      child: Column(
        key: const Key('ink-skeleton-list'),
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: InkSpace.lg),
              child: Row(
                children: [
                  if (leading) ...[
                    const InkSkeleton(width: 40, height: 56),
                    const SizedBox(width: InkSpace.md),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: .7,
                          child: InkSkeleton(height: 14),
                        ),
                        SizedBox(height: InkSpace.sm),
                        FractionallySizedBox(
                          widthFactor: .4,
                          child: InkSkeleton(height: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// The single determinate progress ring (download queue, transfer rows).
/// It never animates on its own: [value] (0–1) is drawn as is, so an idle or
/// offscreen ring costs nothing. An optional [icon] sits in the center
/// (queued, paused or failed state). [label] is the already localized
/// accessible name; the percent is announced as its value.
class InkProgressRing extends StatelessWidget {
  const InkProgressRing({
    super.key,
    required this.value,
    this.size = 40,
    this.icon,
    this.color,
    this.label,
  });
  final double value;
  final double size;
  final IconData? icon;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: label == null
          ? null
          : context.tr('{0} %', [(ratio * 100).round()]),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: size >= 32 ? 3 : 2,
                color: color,
                backgroundColor: colors.outlineVariant,
              ),
            ),
            if (icon != null)
              Icon(icon, size: size * .45, color: color ?? colors.primary),
          ],
        ),
      ),
    );
  }
}
