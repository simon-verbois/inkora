import '../../app/l10n/app_strings.dart';
import '../icons/inkora_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/connection/application/session_controller.dart';
import '../../features/library/application/catalogue_providers.dart';
import '../../features/library/domain/catalogue.dart';
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
    // Prepare the Libraries landing query from SQLite while Home is visible.
    // This fetches no artwork and adds no remote catalogue request. Listening
    // keeps it warm without rebuilding the shell on each feed emission.
    ref.listen(
      catalogueFeedStateProvider(
        const CatalogueQuery(kind: CatalogueKind.series, readingUnits: true),
      ),
      (_, _) {},
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= InkoraLayout.railBreakpoint;
        return Scaffold(
          appBar: AppBar(
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
            bottom: wide,
            child: Column(
              children: [
                if (offline)
                  Material(
                    color: InkoraColors.of(context).raised,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        InkoraNavigation(
                          vertical: true,
                          selectedIndex: navigationShell.currentIndex,
                          onSelect: _select,
                        ),
                      Expanded(child: InkTopFade(child: navigationShell)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : InkoraNavigation(
                  selectedIndex: navigationShell.currentIndex,
                  onSelect: _select,
                ),
        );
      },
    );
  }
}
