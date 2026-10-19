import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_motion.dart';
import 'settings_adaptive_layout.dart';
import 'settings_sections.dart';

String settingsSectionForPath(String path) {
  final section = path.split('/').elementAtOrNull(2);
  return switch (section) {
    null || '' => 'appearance',
    'reading-defaults' || 'library-defaults' => 'reading',
    _ => section,
  };
}

/// Keep the branch Navigator in one stable slot on every destination and resize.
/// Only the settings branch reveals its local navigation pane.
class SettingsWorkspace extends StatefulWidget {
  const SettingsWorkspace({
    super.key,
    required this.path,
    required this.active,
    required this.child,
  });
  final String path;
  final bool active;
  final Widget child;
  @override
  State<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends State<SettingsWorkspace> {
  String _query = '';
  bool _searchOpen = false;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _query = '';
        _searchController.clear();
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchOpen && _searchFocus.canRequestFocus) {
          _searchFocus.requestFocus();
        }
      });
    } else {
      _searchFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = widget.active && useWideSettings(context, bounds.maxWidth);
      final selected = settingsSectionForPath(widget.path);
      final heading = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(24) + 32,
          child: Row(
            key: const Key('settings-sidebar-heading'),
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExcludeSemantics(
                        excluding: _searchOpen,
                        child: LText(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _searchOpen ? 1 : 0),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : InkoraMotion.tab,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Offstage(
                        offstage: value == 0,
                        child: ClipRect(
                          key: const Key('settings-sidebar-search-reveal'),
                          clipper: _SearchRevealClipper(value),
                          child: child,
                        ),
                      ),
                      child: ExcludeFocus(
                        excluding: !_searchOpen,
                        child: ExcludeSemantics(
                          excluding: !_searchOpen,
                          child: IgnorePointer(
                            ignoring: !_searchOpen,
                            child: ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: TextField(
                                key: const Key('settings-sidebar-search'),
                                controller: _searchController,
                                focusNode: _searchFocus,
                                decoration: InputDecoration(
                                  hintText: context.tr('Search'),
                                ),
                                onChanged: (value) {
                                  final query = value.toLowerCase().trim();
                                  if (query != _query) {
                                    setState(() => _query = query);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('settings-sidebar-search-toggle'),
                tooltip: context.tr(_searchOpen ? 'Close' : 'Search settings'),
                icon: Icon(_searchOpen ? InkIcons.x : InkIcons.magnifyingGlass),
                onPressed: _toggleSearch,
              ),
            ],
          ),
        ),
      );
      return ScrollConfiguration(
        behavior: wide
            ? ScrollConfiguration.of(context).copyWith(scrollbars: false)
            : ScrollConfiguration.of(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Offstage(
              offstage: !wide,
              child: ExcludeFocus(
                excluding: !wide,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: 248,
                    child: Padding(
                      key: const Key('settings-sidebar'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ListView(
                              controller: _scrollController,
                              primary: false,
                              key: const PageStorageKey(
                                'settings-sidebar-scroll',
                              ),
                              padding: const EdgeInsets.only(bottom: 8),
                              children: [
                                heading,
                                for (final entry in settingsSections.where(
                                  (entry) =>
                                      '${context.tr(entry.$2)} ${context.tr(entry.$3)}'
                                          .toLowerCase()
                                          .contains(_query),
                                ))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: ListTile(
                                      minTileHeight: 48,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                      key: ValueKey(
                                        'settings-category-${entry.$1}',
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      selected: selected == entry.$1,
                                      selectedTileColor: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      leading: Icon(entry.$4, size: 22),
                                      title: LText(entry.$2),
                                      onTap: () {
                                        if (widget.path !=
                                                '/settings/${entry.$1}' &&
                                            !(widget.path == '/settings' &&
                                                entry.$1 == 'appearance')) {
                                          context.go('/settings/${entry.$1}');
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (wide)
              VerticalDivider(
                key: const Key('settings-sidebar-divider'),
                width: 16,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            Expanded(
              child: SettingsPaneScope(wide: wide, child: widget.child),
            ),
          ],
        ),
      );
    },
  );
}

/// Reveal the full-width field from its adjacent search icon without relayout.
class _SearchRevealClipper extends CustomClipper<Rect> {
  const _SearchRevealClipper(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - fraction), 0, size.width, size.height);

  @override
  bool shouldReclip(_SearchRevealClipper oldClipper) =>
      fraction != oldClipper.fraction;
}
