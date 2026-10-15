import '../../app/l10n/app_strings.dart';
import '../icons/inkora_icons.dart';

import 'package:flutter/material.dart';

import '../theme/inkora_theme.dart';

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
    required this.child,
    this.framed = true,
    this.padding,
  });
  final String? title;
  final IconData? icon;
  final Widget child;
  final bool framed;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final colors = InkoraColors.of(context);
    final contentPadding =
        padding ?? (framed ? const EdgeInsets.all(12) : EdgeInsets.zero);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: framed
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.raised.withValues(alpha: .45), colors.panel],
                ),
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(InkoraLayout.radius),
              )
            : null,
        child: Column(
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
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colors.heading,
                                  ),
                            ),
                          ),
                        ),
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
        ),
      ),
    );
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

/// A small background overlay softens scrolling content under the app header.
/// It adds no layout inset and never consumes gestures or reader image memory.
class InkTopFade extends StatelessWidget {
  const InkTopFade({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 18,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [background, background.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class InkEmptyState extends StatelessWidget {
  const InkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.label,
    this.comingSoon = false,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  final String? label;
  final bool comingSoon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        LText(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LText(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (comingSoon)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Chip(label: LText('Coming later')),
          ),
        if (action != null && label != null) ...[
          const SizedBox(height: 12),
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
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : LText(subtitle!),
      onTap: onTap,
      trailing: trailing ?? const Icon(InkIcons.caretRight),
    ),
  );
}

Future<T?> showInkSheet<T>({
  required BuildContext context,
  required Widget child,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useRootNavigator: true,
  useSafeArea: true,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    ),
  ),
);

void showFeaturePlaceholder(
  BuildContext context, {
  required String title,
  required String message,
}) => showInkSheet<void>(
  context: context,
  child: SingleChildScrollView(
    child: InkEmptyState(
      icon: InkIcons.bookOpen,
      title: title,
      message: message,
      comingSoon: true,
    ),
  ),
);
