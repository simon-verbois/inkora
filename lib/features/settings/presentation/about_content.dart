import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
          framed: false,
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
            framed: false,
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
        OutlinedButton(
          key: const Key('about-guided-setup'),
          onPressed: () => context.push('/setup?edit=true'),
          child: const LText('Guided setup'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('about-licenses'),
          onPressed: information.asData == null
              ? null
              : () => showLicensePage(
                  context: context,
                  applicationName: 'Inkora',
                  applicationVersion: information.requireValue.version,
                ),
          child: const LText('Open-source licenses'),
        ),
        const SizedBox(height: 16),
        const Center(child: _SupportButton()),
      ],
    );
  }
}

/// The official image is bundled locally; only an explicit press opens the
/// creator's fixed support address in the external browser.
class _SupportButton extends StatefulWidget {
  const _SupportButton();

  @override
  State<_SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends State<_SupportButton> {
  static final _destination = Uri.https('buymeacoffee.com', '/simonverbois');
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!await launchUrl(
        _destination,
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('External browser unavailable');
      }
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to open this link.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('Buy Me a Coffee'),
    link: true,
    enabled: !_opening,
    child: TextButton(
      key: const Key('about-support'),
      onPressed: _opening ? null : _open,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        fixedSize: const Size(178, 50),
      ),
      child: Image.asset(
        'assets/branding/buy-me-a-coffee.png',
        width: 178,
        height: 50,
        fit: BoxFit.contain,
        cacheWidth: (178 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
          1,
          545,
        ),
        excludeFromSemantics: true,
      ),
    ),
  );
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
