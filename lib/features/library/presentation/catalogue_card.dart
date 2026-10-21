import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../../../offline/application/offline_coordinator.dart';
import '../../../offline/data/download_store.dart';
import '../../../offline/presentation/download_book_action.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
import 'book_cover.dart';
import 'catalogue_presentation.dart';
import 'progress_format.dart';

int catalogueColumnCount(double extent, {int? columns}) =>
    columns?.clamp(2, 7) ??
    (extent < 600 ? 3 : ((extent - 32) / 175).floor().clamp(3, 6));

double catalogueCoverWidth(double extent, {int? columns}) {
  final count = catalogueColumnCount(extent, columns: columns);
  final gap = extent < 600 ? 10.0 : 12.0;
  return (extent - 32 - (count - 1) * gap) / count;
}

typedef _TileAction = ({String label, IconData icon, VoidCallback run});

/// The shared cover tile of shelves and grids: artwork with the standard
/// badges (volume number, read, reading progress, offline, unavailable), the
/// title and one metadata/progress line. A tap runs the primary action; a
/// long press opens a context menu when there is more than one action. Screen
/// readers hear one combined label and get the menu entries as custom actions.
class InkCoverTile extends ConsumerWidget {
  const InkCoverTile({
    super.key,
    required this.item,
    this.resume,
    this.titleMaxLines = 2,
    this.onOpen,
    this.coverItem,
    this.openLabel,
    this.downloadedJob,
    this.onRemoveDownload,
    this.offlineBadge = true,
    this.resumeOpensBook = true,
  });
  final CatalogueItem item;
  final CatalogueItem? coverItem;
  final ResumeEntry? resume;
  final int titleMaxLines;
  final ValueChanged<CatalogueItem>? onOpen;

  /// Menu label of the tap action. Defaults to Read book, Continue reading or
  /// View details depending on the item.
  final String? openLabel;

  /// Completed download already known by the caller (Downloads gallery).
  final DownloadJob? downloadedJob;
  final Future<void> Function(String jobId)? onRemoveDownload;

  /// Whether to show the offline badge (redundant inside Downloads).
  final bool offlineBadge;

  /// Whether a series card with a [resume] position opens that book (Continue
  /// reading) or the series details (Up next, which then offers the book in
  /// its context menu).
  final bool resumeOpensBook;

  void _open(BuildContext context) =>
      onOpen == null ? openCatalogueItem(context, item) : onOpen!(item);

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    DownloadJob? job;
    for (final candidate
        in ref.read(downloadsProvider).asData?.value ?? const <DownloadJob>[]) {
      if (candidate.bookId == item.id &&
          candidate.state != DownloadState.cancelled) {
        job = candidate;
      }
    }
    try {
      await queueBookDownload(
        ref,
        item.id,
        job:
            job?.state == DownloadState.paused ||
                job?.state == DownloadState.failed
            ? job
            : null,
      );
      if (context.mounted) notifyInk(context, 'Queued');
    } catch (_) {
      if (context.mounted) {
        notifyInk(
          context,
          'Unable to queue this download. Check connection and storage quota.',
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    if (!await confirmRemoveDownload(context, item.title) || !context.mounted) {
      return;
    }
    try {
      await removeBookDownload(
        ref,
        item.id,
        job: downloadedJob,
        onRemoveDownload: onRemoveDownload,
      );
    } catch (_) {
      if (context.mounted) {
        notifyInk(context, 'Unable to remove this download. Try again.');
      }
    }
  }

  List<_TileAction> _actions(
    BuildContext context,
    WidgetRef ref,
    bool downloaded,
  ) {
    if (!item.canOpen) return const [];
    final book = item.kind == CatalogueKind.book;
    final continues = !book && resume != null && resumeOpensBook;
    final actions = <_TileAction>[
      (
        label:
            openLabel ??
            (book
                ? 'Read book'
                : continues
                ? 'Continue reading'
                : 'View details'),
        icon: book || continues ? InkIcons.bookOpen : InkIcons.info,
        run: () => _open(context),
      ),
      if (!book && resume != null)
        continues
            ? (
                label: 'View details',
                icon: InkIcons.info,
                run: () => openCatalogueItem(context, item),
              )
            : (
                label: 'Read book',
                icon: InkIcons.bookOpen,
                run: () => openCatalogueItem(context, resume!.item),
              ),
      if (book && downloaded)
        (
          label: 'Remove download',
          icon: InkIcons.trash,
          run: () => _remove(context, ref),
        )
      else if (book && item.pageCount > 0)
        (
          label: 'Download volume',
          icon: InkIcons.downloadSimple,
          run: () => _download(context, ref),
        ),
    ];
    // A single entry would only repeat the tap.
    return actions.length < 2 ? const [] : actions;
  }

  Future<void> _menu(
    BuildContext context,
    List<_TileAction> actions,
    Offset? position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject() as RenderBox?;
    final anchor =
        position ??
        (box == null
            ? overlay.size.center(Offset.zero)
            : box.localToGlobal(box.size.center(Offset.zero)));
    final selected = await showMenu<_TileAction>(
      context: context,
      position: RelativeRect.fromRect(
        anchor & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Row(
              children: [
                Icon(action.icon, size: 20),
                const SizedBox(width: InkSpace.md),
                Flexible(child: LText(action.label)),
              ],
            ),
          ),
      ],
    );
    selected?.run();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = InkoraColors.of(context);
    final identity = item.identity;
    final downloaded =
        downloadedJob != null ||
        offlineBadge &&
            ref.watch(
              downloadedIdentitiesProvider.select(
                (value) => value.asData?.value.contains(identity) ?? false,
              ),
            );
    final progress = resume == null
        ? formatItemProgress(strings, item)
        : formatResumeProgress(strings, resume!);
    final title = item.kind == CatalogueKind.book
        ? item.title
        : resume?.seriesTitle ?? item.title;
    final description = resume == null
        ? catalogueDescription(item, context: context)
        : progress.label;
    final read = resume == null && progress.state == ReadingState.read;
    final ratio = resume == null ? null : progress.ratio;
    final actions = _actions(context, ref, downloaded);
    final semantics = [
      title,
      description,
      if (resume == null && progress.state != ReadingState.unread)
        progress.label,
      if (resume != null) strings.text(readingStateLabel(progress.state)),
      if (downloaded) strings.text('Ready offline'),
    ].join(', ');
    Offset? pressed;
    void longPress() => _menu(context, actions, pressed);
    return Semantics(
      container: true,
      button: true,
      enabled: item.canOpen,
      label: semantics,
      onTap: item.canOpen ? () => _open(context) : null,
      onLongPress: actions.isEmpty ? null : longPress,
      customSemanticsActions: {
        for (final action in actions.skip(1))
          CustomSemanticsAction(label: strings.text(action.label)): action.run,
      },
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: InkRadius.medium,
            key: resume == null ? null : ValueKey('resume-${resume!.item.id}'),
            onTap: item.canOpen ? () => _open(context) : null,
            onTapDown: (details) => pressed = details.globalPosition,
            onLongPress: actions.isEmpty ? null : longPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    BookCover(item: coverItem ?? item),
                    PositionedDirectional(
                      top: InkSpace.xs,
                      end: InkSpace.xs,
                      child: Column(
                        children: [
                          if (!item.canOpen)
                            const InkCoverIconBadge(
                              key: Key('cover-unavailable'),
                              icon: InkIcons.prohibit,
                            )
                          else if (read)
                            InkCoverIconBadge(
                              key: const Key('cover-read'),
                              icon: InkIcons.check,
                              background: colors.success,
                              foreground: theme.colorScheme.surface,
                            ),
                          if (downloaded && item.canOpen)
                            const Padding(
                              padding: EdgeInsets.only(top: InkSpace.xs),
                              child: InkCoverIconBadge(
                                key: Key('cover-offline'),
                                icon: InkIcons.downloadSimple,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (ratio != null)
                      Positioned(
                        left: InkSpace.sm,
                        right: InkSpace.sm,
                        bottom: InkSpace.sm,
                        child: LinearProgressIndicator(
                          key: const Key('cover-progress'),
                          value: ratio,
                          minHeight: 5,
                          backgroundColor: colors.scrim,
                          borderRadius: InkRadius.small,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: InkSpace.xs),
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: catalogueTitleStyle(context, constraints.maxWidth),
                ),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.meta?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small scrim pill drawn over artwork (volume number); no shadow or
/// compositing layer. Shared by cover tiles and volume grids.
class InkCoverBadge extends StatelessWidget {
  const InkCoverBadge({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: InkoraColors.of(context).scrim,
      borderRadius: InkRadius.round,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpace.sm, vertical: 2),
      child: child,
    ),
  );
}

/// Round scrim (or [background]) icon badge over artwork: read, offline,
/// unavailable.
class InkCoverIconBadge extends StatelessWidget {
  const InkCoverIconBadge({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
  });
  final IconData icon;
  final Color? background, foreground;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background ?? InkoraColors.of(context).scrim,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(InkSpace.xs),
      child: Icon(
        icon,
        size: 14,
        color: foreground ?? InkoraColors.of(context).onScrim,
      ),
    ),
  );
}

/// Grid item builder for first loads; the first tile announces loading once.
Widget coverSkeletonBuilder(BuildContext context, int index) => index == 0
    ? Semantics(
        label: context.tr('Loading'),
        excludeSemantics: true,
        child: const CoverTileSkeleton(),
      )
    : const ExcludeSemantics(child: CoverTileSkeleton());

/// Static first-load placeholder with the cover tile geometry.
class CoverTileSkeleton extends StatelessWidget {
  const CoverTileSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(aspectRatio: InkoraLayout.coverRatio, child: InkSkeleton()),
      SizedBox(height: InkSpace.sm),
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: .8,
        child: InkSkeleton(height: 10),
      ),
      SizedBox(height: InkSpace.xs),
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: .5,
        child: InkSkeleton(height: 8),
      ),
    ],
  );
}

TextStyle? catalogueTitleStyle(BuildContext context, double width) =>
    (width < 120
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(fontWeight: FontWeight.w700);

class CatalogueShelf extends StatelessWidget {
  static const maxItems = 10;
  const CatalogueShelf({
    super.key,
    required this.items,
    this.cardWidth = 120,
    this.columns,
    this.resumeEntries = const {},
    this.onOpen,
    this.onViewAll,
    this.viewAllLabel = 'Browse all books',
    this.resumeOpensBook = true,
  });
  final List<CatalogueItem> items;
  final double cardWidth;
  final int? columns;
  final Map<String, ResumeEntry> resumeEntries;
  final ValueChanged<CatalogueItem>? onOpen;
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  /// See [InkCoverTile.resumeOpensBook].
  final bool resumeOpensBook;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final visible = items.take(maxItems).toList(growable: false);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final width = columns != null || constraints.maxWidth >= 600
          ? catalogueCoverWidth(constraints.maxWidth + 32, columns: columns)
          : scale > 1.3
          ? 160.0
          : math
                .min(cardWidth, (constraints.maxWidth - 30) / 3.2)
                .clamp(72.0, 160.0);
      final theme = Theme.of(context);
      final strings = AppStrings.of(context);
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        ellipsis: '…',
      );
      double labelHeight = 0;
      for (final item in visible) {
        final resume = resumeEntries[item.identity] ?? resumeEntries[item.id];
        painter
          ..text = TextSpan(
            text: item.kind == CatalogueKind.book
                ? item.title
                : resume?.seriesTitle ?? item.title,
            style: catalogueTitleStyle(context, width),
          )
          ..maxLines = 1
          ..layout(maxWidth: width);
        final titleHeight = painter.height;
        painter
          ..text = TextSpan(
            text: resume == null
                ? catalogueDescription(item, context: context)
                : formatResumeProgress(strings, resume).label,
            style: theme.textTheme.meta,
          )
          ..maxLines = 1
          ..layout(maxWidth: width);
        labelHeight = math.max(labelHeight, titleHeight + painter.height);
      }
      painter.dispose();
      final gap = columns != null && constraints.maxWidth + 32 >= 600
          ? 12.0
          : 10.0;
      // The end card leads to the full list only when the shelf is truncated.
      final viewAll = onViewAll != null && items.length > maxItems;
      return SizedBox(
        height:
            width / InkoraLayout.coverRatio +
            InkSpace.xs +
            labelHeight.ceilToDouble(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: visible.length + (viewAll ? 1 : 0),
          separatorBuilder: (_, _) => SizedBox(width: gap),
          itemBuilder: (_, index) => SizedBox(
            width: width,
            child: index == visible.length
                ? _ShelfViewAllCard(label: viewAllLabel, onTap: onViewAll!)
                : InkCoverTile(
                    item: visible[index],
                    titleMaxLines: 1,
                    resume:
                        resumeEntries[visible[index].identity] ??
                        resumeEntries[visible[index].id],
                    resumeOpensBook: resumeOpensBook,
                    onOpen: onOpen,
                  ),
          ),
        ),
      );
    },
  );
}

/// The final carousel destination shares cover geometry without loading artwork.
class _ShelfViewAllCard extends StatelessWidget {
  const _ShelfViewAllCard({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: context.tr(label),
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('shelf-view-all-$label'),
            borderRadius: InkRadius.small,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: InkoraLayout.coverRatio,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: InkoraColors.of(context).raised
                          .withValues(alpha: .5),
                      border: Border.all(
                        color: InkoraColors.of(context).border,
                      ),
                      borderRadius: InkRadius.small,
                    ),
                    child: Center(
                      child: Icon(
                        InkIcons.squaresFour,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: InkSpace.xs),
                LText(
                  'View all',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: catalogueTitleStyle(context, constraints.maxWidth),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
