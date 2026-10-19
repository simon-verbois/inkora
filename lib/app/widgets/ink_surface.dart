import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/ui_preferences_provider.dart';
import '../../features/settings/domain/ui_preferences.dart';

/// A single painted surface: alpha affects its fill, never its text or icons.
/// No backdrop capture/blur or per-item compositing layer is introduced.
class InkSurface extends StatelessWidget {
  const InkSurface({
    super.key,
    required this.child,
    this.opacity = 1,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double opacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer.withValues(
        alpha: opacity.clamp(UiPreferences.minPanelOpacity, 1),
      ),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Observe only the overlay preference, leaving underlying content retained.
class InkOverlaySurface extends ConsumerWidget {
  const InkOverlaySurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkSurface(
    opacity: ref.watch(
      uiPreferencesProvider.select(
        (data) => data.asData?.value.panelOpacity ?? .94,
      ),
    ),
    child: child,
  );
}

/// App-bar sizing retains system insets and native route back behavior.
class InkAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InkAppBar({
    super.key,
    required this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
  });
  final Widget title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkOverlaySurface(
        child: AppBar(
          primary: false,
          title: title,
          actions: actions,
          automaticallyImplyLeading: automaticallyImplyLeading,
          backgroundColor: Colors.transparent,
        ),
      ),
    ),
  );
}
