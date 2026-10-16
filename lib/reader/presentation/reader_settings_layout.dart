export '../../app/widgets/ink_slider.dart';

import 'package:flutter/material.dart';

/// Two aligned columns when labels have enough space; one at large text sizes.
/// Shared by document typography, page layout and image-format controls.
class ReaderSettingsGrid extends StatelessWidget {
  const ReaderSettingsGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = constraints.maxWidth >= 520 * scale ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Dense dropdown buttons have one text line. Keep long selected labels inside
/// that line; menus and the long-press/hover tooltip retain their full wording.
class ReaderSettingsSelectedValue extends StatelessWidget {
  const ReaderSettingsSelectedValue(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: text,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
