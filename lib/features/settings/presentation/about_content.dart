import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/release_information.dart';
import '../../../app/widgets/inkora_widgets.dart';

class AboutContent extends ConsumerWidget {
  const AboutContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final information = ref.watch(releaseInformationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InkoraWordmark(size: 36),
              const SizedBox(height: 16),
              const LText(
                'A personal, offline-first reading home for your Komga libraries.',
              ),
              const SizedBox(height: 12),
              ...information.when(
                data: (info) => [
                  LText('Version {0}', arguments: [info.version]),
                ],
                loading: () => [const LinearProgressIndicator()],
                error: (_, _) => [
                  const LText('Release information unavailable.'),
                  TextButton(
                    onPressed: () => ref.invalidate(releaseInformationProvider),
                    child: const LText('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (information.asData?.value case final info?) ...[
          InkPanel(
            child: ExpansionTile(
              key: const Key('about-changelog'),
              title: const LText('Changelog'),
              tilePadding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < info.sections.length; i++)
                  _ChangelogSection(
                    section: info.sections[i],
                    initiallyExpanded: i == 0,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        InkPanel(
          title: context.tr('Ebooks'),
          child: InkEmptyState(
            icon: InkIcons.bookOpen,
            title: context.tr('EPUB and local PDF reading'),
            message: context.tr(
              'Read EPUB and PDF books with adjustable text, bookmarks and synchronized progress.',
            ),
            comingSoon: false,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: information.asData == null
              ? null
              : () => showLicensePage(
                  context: context,
                  applicationName: 'Inkora',
                  applicationVersion: information.requireValue.version,
                ),
          child: const LText('Open-source licenses'),
        ),
      ],
    );
  }
}

class _ChangelogSection extends StatelessWidget {
  const _ChangelogSection({
    required this.section,
    required this.initiallyExpanded,
  });
  final ChangelogSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(section.title),
    initiallyExpanded: initiallyExpanded,
    children: [
      SelectionArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final block in section.blocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: switch (block.kind) {
                    ChangelogBlockKind.heading => Semantics(
                      header: true,
                      child: Text(
                        block.text,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    ChangelogBlockKind.paragraph => Text(block.text),
                    ChangelogBlockKind.bullet => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(block.text)),
                      ],
                    ),
                  },
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
