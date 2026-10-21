import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/ui_preferences_provider.dart';
import '../theme/inkora_theme.dart';
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
        borderRadius: InkRadius.large,
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
