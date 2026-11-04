import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';

/// The device-language welcome keeps its actions after the feature presentation.
class SetupIntroduction extends StatelessWidget {
  const SetupIntroduction({super.key, required this.footer});
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkContent(
      maxWidth: 620,
      child: ListView(
        key: const Key('setup-introduction-scroll'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        children: [
          const Center(child: InkoraWordmark(size: 40)),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: LText(
              'Welcome to Inkora',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          for (final feature in const [
            (
              InkIcons.bookOpen,
              'Read your way',
              'Enjoy manga, comics and webtoons with reading settings for each library.',
            ),
            (
              InkIcons.bookmarks,
              'Ebooks',
              'Read EPUB and PDF books with adjustable text, bookmarks and synchronized progress.',
            ),
            (
              InkIcons.downloadSimple,
              'Take your books offline',
              'Download volumes to read without a connection.',
            ),
            (
              InkIcons.arrowsClockwise,
              'Keep your place',
              'Reading progress is saved on your device and synchronized with Komga when connected.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(InkRadius.m),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          feature.$1,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: LText(
                            feature.$2,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LText(
                          feature.$3,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          footer,
        ],
      ),
    );
  }
}
