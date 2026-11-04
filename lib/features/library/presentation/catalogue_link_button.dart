import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/catalogue_metadata.dart';

/// Server-owned website labels open only after the user reviews the destination.
class CatalogueLinkButton extends StatefulWidget {
  const CatalogueLinkButton({super.key, required this.link});
  final CatalogueLink link;
  @override
  State<CatalogueLinkButton> createState() => _CatalogueLinkButtonState();
}

class _CatalogueLinkButtonState extends State<CatalogueLinkButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final uri = Uri.tryParse(widget.link.url);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException('Invalid website URL');
      }
      if (!await confirmInk(
            context,
            title: 'Open external link?',
            message: 'This link opens in your browser outside the app.',
            confirmLabel: 'Open link',
            details: SelectableText(uri.toString()),
          ) ||
          !mounted) {
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Website launcher unavailable');
      }
    } catch (_) {
      if (mounted) notifyInk(context, 'Unable to open this link.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(widget.link.url)?.host.toLowerCase();
    final asset = switch (host) {
      'anilist.co' || 'www.anilist.co' => 'anilist',
      'mangadex.org' || 'www.mangadex.org' => 'mangadex',
      'mangaupdates.com' || 'www.mangaupdates.com' => 'mangaupdates',
      'openlibrary.org' || 'www.openlibrary.org' => 'openlibrary',
      _ => null,
    };
    return TextButton(
      key: ValueKey('catalogue-link-${widget.link.url}'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        minimumSize: const Size(0, 48),
        alignment: AlignmentDirectional.centerStart,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(borderRadius: InkRadius.medium),
      ),
      onPressed: _opening ? null : _open,
      child: Row(
        children: [
          ExcludeSemantics(
            child: asset == null
                ? const Icon(InkIcons.globe, size: 24)
                : Image.asset(
                    'assets/websites/$asset.png',
                    width: 24,
                    height: 24,
                    cacheWidth: 64,
                    cacheHeight: 64,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.link.label.isEmpty
                  ? context.tr('Reference')
                  : widget.link.label,
            ),
          ),
          const SizedBox(width: 8),
          const ExcludeSemantics(child: Icon(InkIcons.caretRight, size: 18)),
        ],
      ),
    );
  }
}

/// Website actions adapt to their local width and keep complete site names.
/// Bundled favicons require no extra network requests while browsing metadata.
class CatalogueLinks extends StatelessWidget {
  const CatalogueLinks({super.key, required this.links});
  final List<CatalogueLink> links;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final columns = (constraints.maxWidth / (240 * scale)).floor().clamp(
        1,
        3,
      );
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final link in links)
            SizedBox(
              width: width,
              child: CatalogueLinkButton(link: link),
            ),
        ],
      );
    },
  );
}
