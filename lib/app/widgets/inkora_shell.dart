import '../../app/l10n/app_strings.dart';
import '../icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/application/session_controller.dart';
import '../theme/inkora_theme.dart';

/// Shared offline framing around the Home-backed page stack.
class InkoraShell extends ConsumerWidget {
  const InkoraShell({super.key, required this.child, this.currentPath = '/'});
  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(sessionProvider.select((s) => s.offline));
    // Series artwork extends behind the status bar at every window width.
    // Each pane/header keeps its own controls inside the relevant safe area.
    final fullBleedSeries =
        !offline && currentPath.startsWith('/catalogue/series/');
    return Scaffold(
      body: Builder(
        builder: (context) => SafeArea(
          top: !fullBleedSeries,
          bottom: false,
          child: Column(
            children: [
              if (offline)
                Material(
                  key: const ValueKey('offline-banner'),
                  color: InkoraColors.of(context).raised,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: InkSpace.lg,
                      vertical: InkSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(InkIcons.cloudSlash, size: 18),
                        SizedBox(width: InkSpace.sm),
                        Expanded(
                          child: LText(
                            'Offline · saved catalogue and downloaded books remain available.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(key: const ValueKey('shell-pages'), child: child),
            ],
          ),
        ),
      ),
    );
  }
}
