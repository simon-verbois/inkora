import 'ink_divider.dart';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/inkora_theme.dart';

/// Shared category rhythm for preference pages, setup and reader forms.
class InkSettingsHeading extends StatelessWidget {
  const InkSettingsHeading({
    super.key,
    required this.title,
    this.first = false,
  });
  final String title;
  final bool first;
  static TextStyle? titleStyleOf(BuildContext context) =>
      Theme.of(context).textTheme.sectionTitle
          ?.copyWith(color: InkoraColors.of(context).heading);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!first) ...[
          const InkDivider(height: 1),
          const SizedBox(height: 16),
        ],
        Semantics(
          header: true,
          child: LText(title, style: titleStyleOf(context)),
        ),
      ],
    ),
  );
}

class InkSettingsSection extends StatelessWidget {
  const InkSettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.first = false,
  });
  final String title;
  final Widget child;
  final bool first;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkSettingsHeading(title: title, first: first),
      child,
    ],
  );
}
