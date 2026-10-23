import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n/app_strings.dart';
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
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(
      key: ValueKey('catalogue-link-${widget.link.url}'),
      onPressed: _opening ? null : _open,
      child: Text(
        widget.link.label.isEmpty ? context.tr('Reference') : widget.link.label,
      ),
    ),
  );
}

/// Metadata websites in reading order, three columns with naturally sized rows.
class CatalogueLinks extends StatelessWidget {
  const CatalogueLinks({super.key, required this.links});
  final List<CatalogueLink> links;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var start = 0; start < links.length; start += 3)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < 3; column++)
              Expanded(
                child: start + column < links.length
                    ? CatalogueLinkButton(link: links[start + column])
                    : const SizedBox.shrink(),
              ),
          ],
        ),
    ],
  );
}
