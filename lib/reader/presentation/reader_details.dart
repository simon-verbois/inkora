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

/// Comic readers return to their existing covered series route when possible.
/// Ebooks expose book facts in place: legacy book routes redirect to reading.
Future<void> openReaderDetails(
  BuildContext context,
  ReaderManifest manifest,
) async {
  if (!manifest.isDocument && manifest.seriesId?.isNotEmpty == true) {
    final route = GoRouterState.of(context);
    if (route.name == 'series-reader' &&
        route.pathParameters['id'] == manifest.seriesId) {
      context.pop();
    } else {
      // A shell route pushed above a retained root reader duplicates the shell
      // when goBranch restores its history. Leave the reader before returning
      // to the shell; its existing origin remains underneath for Back.
      context.pushReplacementNamed(
        'catalogue-detail',
        pathParameters: {'kind': 'series', 'id': manifest.seriesId!},
      );
    }
    return;
  }
  await showInkSheet<void>(
    context: context,
    child: ReaderBookDetails(manifest: manifest),
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
    tooltip: context.tr(
      !manifest.isDocument && manifest.seriesId?.isNotEmpty == true
          ? 'Open series'
          : 'Book details',
    ),
    icon: Icon(
      !manifest.isDocument && manifest.seriesId?.isNotEmpty == true
          ? InkIcons.books
          : InkIcons.info,
    ),
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
