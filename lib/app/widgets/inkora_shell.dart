import '../../app/l10n/app_strings.dart';
import '../icons/inkora_icons.dart';
import 'ink_surface.dart';
import '../../features/settings/application/ui_preferences_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/connection/application/session_controller.dart';
import '../theme/inkora_theme.dart';
import 'inkora_widgets.dart';
import 'inkora_navigation.dart';
import '../../features/settings/presentation/settings_workspace.dart';
import '../../features/settings/presentation/settings_adaptive_layout.dart';

class InkoraShell extends ConsumerWidget {
  const InkoraShell({
    super.key,
    required this.navigationShell,
    this.currentPath = '/',
  });
  final StatefulNavigationShell navigationShell;
  final String currentPath;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(sessionProvider.select((s) => s.offline));
    final floating = ref.watch(
      uiPreferencesProvider.select(
        (data) => data.asData?.value.floatingNavigation ?? true,
      ),
    );
    final opacity = ref.watch(
      uiPreferencesProvider.select(
        (data) => data.asData?.value.panelOpacity ?? .94,
      ),
    );
    final wideSettings =
        navigationShell.currentIndex == 2 &&
        useWideSettings(
          context,
          MediaQuery.sizeOf(context).width -
              MediaQuery.paddingOf(context).horizontal,
        );
    return Scaffold(
      extendBody: floating,
      appBar: InkAppBar(
        automaticallyImplyLeading: !wideSettings,
        title: const InkoraWordmark(),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (offline)
              Material(
                color: InkoraColors.of(context).raised,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(InkIcons.cloudSlash, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: LText(
                          'Offline · saved catalogue and downloaded books remain available.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SettingsWorkspace(
                path: currentPath,
                active: navigationShell.currentIndex == 2,
                child: navigationShell,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : InkoraNavigation(
              floating: floating,
              opacity: opacity,
              selectedIndex: navigationShell.currentIndex,
              onSelect: _select,
            ),
    );
  }
}
