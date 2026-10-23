import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_motion.dart';
import 'settings_adaptive_layout.dart';
import 'settings_navigation.dart';

String settingsSectionForPath(String path) {
  final section = path.split('/').elementAtOrNull(2);
  return switch (section) {
    null || '' => 'appearance',
    'reading-defaults' || 'library-defaults' => 'reading',
    _ => section,
  };
}

/// Keep the settings Navigator in one stable slot across categories and resize.
/// Settings routes reveal their local navigation pane. In wide windows
/// its local category pane remains beside the selected page and its heading is the
/// page's only header level, so category pages there have no screen header.
class SettingsWorkspace extends StatefulWidget {
  const SettingsWorkspace({
    super.key,
    required this.path,
    required this.active,
    required this.child,
    this.wide,
  });
  final String path;
  final bool active;
  final Widget child;

  /// The shell's [useWideSettings] decision for the whole window; null
  /// derives it from this workspace's own width.
  final bool? wide;
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
      final wide =
          widget.active &&
          (widget.wide ?? useWideSettings(context, bounds.maxWidth));
      final selected = settingsSectionForPath(widget.path);
      final heading = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(24) + 32,
          child: Stack(
            key: const Key('settings-sidebar-heading'),
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: _searchOpen,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('settings-sidebar-back'),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(InkIcons.caretLeft),
                    ),
                    Expanded(
                      child: LText(
                        'Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('settings-sidebar-search-toggle'),
                      tooltip: context.tr('Search settings'),
                      icon: const Icon(InkIcons.magnifyingGlass),
                      onPressed: _toggleSearch,
                    ),
                  ],
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
                      child: SettingsSearchField(
                        fieldKey: const Key('settings-sidebar-search'),
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onClose: _toggleSearch,
                        onChanged: (value) {
                          final query = value.toLowerCase().trim();
                          if (query != _query) setState(() => _query = query);
                        },
                      ),
                    ),
                  ),
                ),
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
                                ...settingsMenu(
                                  context,
                                  query: _query,
                                  entry: (entry, path) => SettingsNavTile(
                                    key: ValueKey(
                                      'settings-category-${entry.id}',
                                    ),
                                    selected: selected == entry.id,
                                    leading: Icon(entry.icon, size: 22),
                                    title: LText(entry.title),
                                    subtitle: path == null ? null : Text(path),
                                    onTap: () {
                                      if (widget.path !=
                                              '/settings/${entry.id}' &&
                                          !(widget.path == '/settings' &&
                                              entry.id == 'appearance')) {
                                        context.go('/settings/${entry.id}');
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
              // Wide category pages have no header, so the pane applies the
              // status-bar inset; the SafeArea stays mounted in both states.
              child: SafeArea(
                top: wide,
                left: false,
                right: false,
                bottom: false,
                child: SettingsPaneScope(wide: wide, child: widget.child),
              ),
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
