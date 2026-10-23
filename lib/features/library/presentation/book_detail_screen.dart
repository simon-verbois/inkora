import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../offline/presentation/download_book_action.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_filters.dart';
import 'book_cover.dart';
import 'catalogue_detail_widgets.dart';
import 'catalogue_presentation.dart';
import 'series_header.dart';

/// Individual book facts use the same hero, Back and metadata vocabulary as
/// series details. Reading is an explicit action and retains this page below it.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(catalogueItemProvider((CatalogueKind.book, id)));
    final item = data.asData?.value;
    return Scaffold(
      body: Stack(
        children: [
          if (item != null) Positioned.fill(child: SeriesBackdrop(item: item)),
          InkFloatingHeader(
            transparentAtRest: true,
            title: item == null ? null : Text(item.title),
            body: InkContent(
              maxWidth: 1120,
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => InkEmptyState(
                  icon: InkIcons.warningCircle,
                  title: 'Details unavailable',
                  message: 'Unable to open saved details.',
                  label: 'Retry',
                  action: () => ref.invalidate(
                    catalogueItemProvider((CatalogueKind.book, id)),
                  ),
                ),
                data: (item) => item == null
                    ? const InkEmptyState(
                        icon: InkIcons.bookOpen,
                        title: 'Item unavailable',
                        message: 'This item is not in the saved catalogue.',
                      )
                    : SingleChildScrollView(
                        key: ValueKey('book-detail-$id'),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.paddingOf(context).bottom,
                        ),
                        child: LayoutBuilder(
                          builder: (context, bounds) {
                            final hero = Padding(
                              padding: const EdgeInsets.fromLTRB(
                                InkSpace.lg,
                                InkSpace.sm,
                                InkSpace.lg,
                                InkSpace.lg,
                              ),
                              child: BookDetailHero(item: item),
                            );
                            final about = Padding(
                              padding: const EdgeInsets.all(InkSpace.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (item.summary.isNotEmpty)
                                    SeriesSynopsis(summary: item.summary),
                                  const SizedBox(height: InkSpace.lg),
                                  LText(
                                    'Publication details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .sectionTitle,
                                  ),
                                  const SizedBox(height: InkSpace.sm),
                                  CatalogueMetadataSection(
                                    metadata: item.metadata,
                                    complete: true,
                                  ),
                                ],
                              ),
                            );
                            return bounds.maxWidth >= 800 &&
                                    MediaQuery.textScalerOf(context).scale(1) <=
                                        1.5
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          InkSpace.lg,
                                          InkSpace.sm,
                                          InkSpace.lg,
                                          InkSpace.lg,
                                        ),
                                        child: BookCover(
                                          item: item,
                                          width: (bounds.maxWidth * .30).clamp(
                                            240.0,
                                            336.0,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    InkSpace.lg,
                                                    InkSpace.sm,
                                                    InkSpace.lg,
                                                    InkSpace.lg,
                                                  ),
                                              child: BookDetailHero(
                                                item: item,
                                                showCover: false,
                                              ),
                                            ),
                                            about,
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [hero, about],
                                  );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookDetailHero extends ConsumerWidget {
  const BookDetailHero({super.key, required this.item, this.showCover = true});
  final CatalogueItem item;
  final bool showCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(
      resumeEntriesProvider.select(
        (value) =>
            value.asData?.value.any(
              (entry) => !entry.onDeck && entry.item.id == item.id,
            ) ??
            false,
      ),
    );
    final theme = Theme.of(context);
    final authors = item.metadata.authors.map((author) => author.name).toSet();
    final information = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            item.title,
            key: const Key('book-detail-title'),
            style: theme.textTheme.screenTitle,
          ),
        ),
        if (authors.isNotEmpty) ...[
          const SizedBox(height: InkSpace.sm),
          Text(authors.join(', '), style: theme.textTheme.bodyMedium),
        ],
        if (item.readingStatus == ReadingStatus.completed) ...[
          const SizedBox(height: InkSpace.sm),
          const Chip(label: LText('Read')),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showCover)
          information
        else
          LayoutBuilder(
            builder: (context, bounds) {
              final cover = BookCover(item: item, width: 112);
              return bounds.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cover,
                        const SizedBox(height: InkSpace.lg),
                        information,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        cover,
                        const SizedBox(width: InkSpace.lg),
                        Expanded(child: information),
                      ],
                    );
            },
          ),
        const SizedBox(height: InkSpace.lg),
        if (item.canOpen)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('book-detail-read'),
                  onPressed: () => openBookReader(context, item),
                  icon: const Icon(InkIcons.play),
                  label: LText(
                    reading || item.readingStatus == ReadingStatus.inProgress
                        ? 'Continue reading'
                        : 'Read book',
                  ),
                ),
              ),
              const SizedBox(width: InkSpace.sm),
              DownloadBookAction(bookId: item.id, title: item.title),
            ],
          )
        else
          const LText('Unavailable or removed. Saved metadata is retained.'),
      ],
    );
  }
}
