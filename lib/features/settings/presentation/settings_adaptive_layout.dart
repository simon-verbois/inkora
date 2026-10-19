import 'package:flutter/material.dart';

/// Two useful panes need a 248px menu and at least 736px of form space.
/// Window geometry, rather than device identity, handles split-screen as well.
bool useWideSettings(BuildContext context, double width) {
  final size = MediaQuery.sizeOf(context);
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return width >= 1000 && size.width > size.height && textScale <= 1.3;
}

/// The existing route/editor owns state; this scope only reduces duplicate chrome.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    super.key,
    required this.wide,
    required super.child,
  });
  final bool wide;
  static bool wideOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPaneScope>()?.wide ??
      false;
  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) =>
      wide != oldWidget.wide;
}

/// Related groups use two columns only when both retain a comfortable width.
/// The same child slots remain mounted across width changes.
class SettingsColumns extends StatelessWidget {
  const SettingsColumns({super.key, required this.first, required this.second});
  final Widget first, second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final split =
          SettingsPaneScope.wideOf(context) &&
          bounds.maxWidth >= 720 * MediaQuery.textScalerOf(context).scale(1);
      final width = split ? (bounds.maxWidth - 24) / 2 : bounds.maxWidth;
      return Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [
          SizedBox(width: width, child: first),
          SizedBox(width: width, child: second),
        ],
      );
    },
  );
}
