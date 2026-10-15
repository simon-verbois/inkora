import 'package:flutter/material.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';

/// A short product introduction, with future capabilities explicitly labeled.
class SetupIntroduction extends StatelessWidget {
  const SetupIntroduction({super.key});

  @override
  Widget build(BuildContext context) => InkContent(
    maxWidth: InkoraLayout.maxSettingsWidth,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LText(
          'Welcome to Inkora',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        for (final feature in const [
          (
            InkIcons.books,
            'Your libraries, together',
            'Browse and discover series from your Komga libraries.',
          ),
          (
            InkIcons.bookOpen,
            'Read your way',
            'Enjoy manga, comics and webtoons with reading settings for each library.',
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
          (
            InkIcons.bookmarks,
            'Ebooks',
            'Read EPUB and PDF books with adjustable text, bookmarks and synchronized progress.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(feature.$1, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        feature.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      LText(feature.$3),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
