import '../../app/theme/inkora_theme.dart';

import 'package:flutter/material.dart';

import '../../app/l10n/app_strings.dart';
import '../domain/ebook_style.dart';
import '../domain/reading_settings.dart';
import 'reading_colors.dart';
import 'ebook_fonts.dart';
import '../../app/icons/inkora_icons.dart';

class EbookStylePicker extends StatelessWidget {
  const EbookStylePicker({
    super.key,
    required this.settings,
    required this.onSelected,
  });
  final ReadingSettings settings;
  final ValueChanged<EbookStyle> onSelected;
  Widget _sample(EbookStyle style) => Text(
    'Aa',
    softWrap: false,
    maxLines: 1,
    style: TextStyle(
      fontSize: 30,
      height: 1.2,
      fontFamily: style.fontChoice.previewFamily,
      fontFamilyFallback: [style.fontChoice.fallback],
    ),
  );

  Widget _caption(BuildContext context, EbookStyle style) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LText(style.label),
      if (!style.publisherStyles) ...[
        const SizedBox(height: 4),
        LText(
          style.fontChoice.label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: style.background.inkColor),
        ),
      ],
    ],
  );

  Widget _selection(EbookStyle style) => SizedBox(
    width: 20,
    child: style.matches(settings)
        ? const Icon(InkIcons.check, size: 20)
        : null,
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LText('Choose a template. You can adjust it afterwards.'),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
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
                          borderRadius: InkRadius.medium,
                        ),
                      ),
                      onPressed: () => onSelected(style),
                      child: width / scale < 240
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _sample(style)),
                                    _selection(style),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _caption(context, style),
                              ],
                            )
                          : Row(
                              children: [
                                SizedBox(
                                  width: 60 * scale,
                                  child: _sample(style),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: _caption(context, style)),
                                const SizedBox(width: 8),
                                _selection(style),
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
