import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons/inkora_icons.dart';
import '../../app/l10n/app_strings.dart';
import '../../app/widgets/inkora_widgets.dart';
import '../../features/library/application/catalogue_providers.dart';
import '../../features/library/domain/catalogue.dart';
import '../../features/library/presentation/book_cover.dart';
import '../../features/library/presentation/catalogue_detail_widgets.dart';
import '../domain/reader_manifest.dart';
import 'reader_system_ui.dart';

/// Open parent facts above the retained reader; Back restores its live position.
Future<void> openReaderSeries(
  BuildContext context,
  ReaderManifest manifest, {
  bool immersiveOnReturn = false,
}) async {
  if (manifest.seriesId?.isNotEmpty != true) return;
  final dismissed = context.pushNamed<void>(
    'reader-parent',
    pathParameters: {'id': manifest.seriesId!},
    queryParameters: {'book': manifest.bookId},
  );
  unawaited(ReaderSystemUi.setImmersive(false));
  await dismissed;
  if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
    unawaited(ReaderSystemUi.setImmersive(immersiveOnReturn));
  }
}

/// The information button always shows the current book without leaving it.
Future<void> openReaderDetails(BuildContext context, ReaderManifest manifest) =>
    showInkSheet<void>(
      context: context,
      child: ReaderBookDetails(manifest: manifest),
    );

class ReaderSeriesButton extends StatelessWidget {
  const ReaderSeriesButton({
    super.key,
    required this.manifest,
    this.onPressed,
    this.immersiveOnReturn,
  });
  final ReaderManifest manifest;
  final VoidCallback? onPressed;
  final bool? immersiveOnReturn;
  @override
  Widget build(BuildContext context) => manifest.seriesId?.isNotEmpty != true
      ? const SizedBox.shrink()
      : TextButton(
          key: const Key('reader-series'),
          onPressed:
              onPressed ??
              () => openReaderSeries(
                context,
                manifest,
                immersiveOnReturn: immersiveOnReturn ?? manifest.isDocument,
              ),
          child: LText(manifest.isDocument ? 'Author' : 'Series'),
        );
}

class ReaderDetailsButton extends StatelessWidget {
  const ReaderDetailsButton({
    super.key,
    required this.manifest,
    this.onPressed,
  });
  final ReaderManifest manifest;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('reader-details'),
    tooltip: context.tr('Book details'),
    icon: const Icon(InkIcons.info),
    onPressed: onPressed ?? () => openReaderDetails(context, manifest),
  );
}

class ReaderBookDetails extends ConsumerWidget {
  const ReaderBookDetails({super.key, required this.manifest});
  final ReaderManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      catalogueItemProvider((CatalogueKind.book, manifest.bookId)),
    );
    final item = state.asData?.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: LText(
                  'Book details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(InkIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item != null) ...[
                BookCover(item: item, width: 80),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  item?.title ?? manifest.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (state.isLoading) const LinearProgressIndicator(),
          if (item?.summary.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            CatalogueSummary(summary: item!.summary),
          ],
          if (item != null) ...[
            const SizedBox(height: 20),
            CatalogueMetadataSection(metadata: item.metadata, complete: true),
          ],
        ],
      ),
    );
  }
}
