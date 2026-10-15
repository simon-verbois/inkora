import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';

import '../../../offline/data/download_store.dart';
import '../../../offline/presentation/download_book_action.dart';
import '../domain/catalogue.dart';
import 'catalogue_presentation.dart';

/// Text-only volume row shared by online and downloaded catalogues.
class VolumeListTile extends StatelessWidget {
  const VolumeListTile({
    super.key,
    required this.item,
    this.onOpen,
    this.completedJob,
    this.onRemoveDownload,
  });
  final CatalogueItem item;
  final ValueChanged<CatalogueItem>? onOpen;
  final DownloadJob? completedJob;
  final Future<void> Function(String jobId)? onRemoveDownload;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('volume-${item.id}'),
    contentPadding: const EdgeInsets.only(left: 0, right: 0),
    title: Text(item.title),
    subtitle: item.canOpen ? null : const LText('Unavailable or removed'),
    enabled: item.canOpen,
    onTap: item.canOpen
        ? () =>
              onOpen == null ? openCatalogueItem(context, item) : onOpen!(item)
        : null,
    trailing: DownloadBookAction(
      bookId: item.id,
      title: item.title,
      enabled: item.canOpen && item.pageCount > 0,
      completedJob: completedJob,
      onRemoveDownload: onRemoveDownload,
    ),
  );
}
