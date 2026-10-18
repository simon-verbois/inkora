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

class InkoraShell extends ConsumerWidget {
  const InkoraShell({
    super.key,
    required this.navigationShell,
    this.showSearch = true,
  });
  final StatefulNavigationShell navigationShell;
  final bool showSearch;

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
        (data) => data.asData?.value.panelOpacity ?? 1,
      ),
    );
    return Scaffold(
      extendBody: floating,
      appBar: InkAppBar(
        title: const InkoraWordmark(),
        actions: [
          if (showSearch)
            IconButton(
              tooltip: context.tr("Search catalogue"),
              icon: const Icon(InkIcons.magnifyingGlass),
              onPressed: () => context.push('/search'),
            ),
        ],
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
            Expanded(child: navigationShell),
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
