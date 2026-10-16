import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_style.dart';
import '../domain/reading_settings.dart';
import 'reading_colors.dart';

class EbookStylePicker extends StatelessWidget {
  const EbookStylePicker({
    super.key,
    required this.settings,
    required this.onSelected,
  });
  final ReadingSettings settings;
  final ValueChanged<EbookStyle> onSelected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LText('Choose a style manually. You can adjust it afterwards.'),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >=
                  400 * MediaQuery.textScalerOf(context).scale(1)
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final style in EbookStyle.values)
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: style.matches(settings),
                    child: OutlinedButton(
                      key: ValueKey('ebook-style-${style.name}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: style.background.paperColor,
                        foregroundColor: style.background.inkColor,
                        side: BorderSide(
                          color: style.matches(settings)
                              ? Theme.of(context).colorScheme.primary
                              : style.background.inkColor.withValues(alpha: .4),
                          width: style.matches(settings) ? 2 : 1,
                        ),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => onSelected(style),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontFamily:
                                  style.font == 'baskerville' ||
                                      style.font == 'serif'
                                  ? 'LibreBaskerville'
                                  : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.fontFamily,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LText(style.label),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
