import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/inkora_theme.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
import 'book_cover.dart';
import '../../settings/domain/ui_preferences.dart';
import 'catalogue_presentation.dart';

double catalogueCoverWidth(double extent, CatalogueDensity density) {
  final available = extent - 32;
  final columns = extent < 600
      ? 3
      : (available / (density == CatalogueDensity.compact ? 145 : 175))
            .floor()
            .clamp(3, 6);
  final gap = extent < 600 ? 10.0 : 12.0;
  return (available - (columns - 1) * gap) / columns;
}

class CatalogueCard extends StatelessWidget {
  const CatalogueCard({
    super.key,
    required this.item,
    this.showMenu = true,
    this.resume,
    this.titleMaxLines = 2,
    this.onRemoveDownload,
    this.onOpen,
    this.coverItem,
    this.coverAction,
  });
  final CatalogueItem item;
  final CatalogueItem? coverItem;
  final Widget? coverAction;
  final bool showMenu;
  final ResumeEntry? resume;
  final int titleMaxLines;
  final ValueChanged<CatalogueItem>? onRemoveDownload;
  final ValueChanged<CatalogueItem>? onOpen;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(InkoraLayout.radius),
          key: resume == null ? null : ValueKey('resume-${resume!.item.id}'),
          onTap: item.canOpen
              ? () => onOpen == null
                    ? openCatalogueItem(context, item)
                    : onOpen!(item)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  BookCover(item: coverItem ?? item),
                  if (resume != null && !resume!.onDeck)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: LinearProgressIndicator(
                        value: resume!.progress,
                        minHeight: 5,
                        backgroundColor: Colors.black.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(6),
                        semanticsLabel: context.tr("Reading progress"),
                        semanticsValue: '${(resume!.progress * 100).round()}%',
                      ),
                    ),
                  if (coverAction != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: Colors.black.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(24),
                        child: IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: coverAction!,
                        ),
                      ),
                    )
                  else if (showMenu &&
                      (onRemoveDownload != null || item.canOpen))
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<String>(
                        tooltip: context.tr('Actions for {0}', [item.title]),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            InkIcons.dotsThreeVertical,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'remove') {
                            onRemoveDownload?.call(item);
                          } else if (value == 'read') {
                            onOpen?.call(item);
                          } else if (value == 'details') {
                            openCatalogueItem(context, item);
                          }
                        },
                        itemBuilder: (_) => onRemoveDownload != null
                            ? const [
                                PopupMenuItem(
                                  value: 'read',
                                  child: LText('Read offline'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: LText('Remove download'),
                                ),
                              ]
                            : [
                                if (item.canOpen)
                                  PopupMenuItem(
                                    value: 'details',
                                    child: LText(
                                      item.kind == CatalogueKind.book
                                          ? 'Read book'
                                          : 'View details',
                                    ),
                                  ),
                              ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.kind == CatalogueKind.book
                    ? item.title
                    : resume?.seriesTitle ?? item.title,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: catalogueTitleStyle(context, constraints.maxWidth),
              ),
              if (resume != null && item.kind != CatalogueKind.book)
                Text(
                  resume!.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                _description(context, item, resume),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    this.density = CatalogueDensity.comfortable,
    this.resumeEntries = const {},
    this.onOpen,
    this.onViewAll,
    this.viewAllLabel = 'Browse all books',
  });
  final List<CatalogueItem> items;
  final double cardWidth;
  final CatalogueDensity density;
  final Map<String, ResumeEntry> resumeEntries;
  final ValueChanged<CatalogueItem>? onOpen;
  final VoidCallback? onViewAll;
  final String viewAllLabel;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final visible = items.take(maxItems).toList(growable: false);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final width = constraints.maxWidth >= 600
          ? catalogueCoverWidth(constraints.maxWidth + 32, density)
          : scale > 1.3
          ? 160.0
          : math
                .min(cardWidth, (constraints.maxWidth - 30) / 3.2)
                .clamp(72.0, 160.0);
      final theme = Theme.of(context);
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
        double volumeHeight = 0;
        if (resume != null && item.kind != CatalogueKind.book) {
          painter
            ..text = TextSpan(
              text: item.title,
              style: theme.textTheme.bodySmall,
            )
            ..maxLines = 1
            ..layout(maxWidth: width);
          volumeHeight = painter.height;
        }
        painter
          ..text = TextSpan(
            text: _description(context, item, resume),
            style: theme.textTheme.bodySmall,
          )
          ..maxLines = 1
          ..layout(maxWidth: width);
        labelHeight = math.max(
          labelHeight,
          titleHeight + volumeHeight + painter.height,
        );
      }
      painter.dispose();
      return SizedBox(
        height:
            width / InkoraLayout.coverRatio + 4 + labelHeight.ceilToDouble(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: visible.length + (onViewAll == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, index) => SizedBox(
            width: width,
            child: index == visible.length
                ? _ShelfViewAllCard(label: viewAllLabel, onTap: onViewAll!)
                : CatalogueCard(
                    item: visible[index],
                    showMenu: false,
                    titleMaxLines: 1,
                    resume:
                        resumeEntries[visible[index].identity] ??
                        resumeEntries[visible[index].id],
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
            borderRadius: BorderRadius.circular(6),
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
                      borderRadius: BorderRadius.circular(6),
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
                const SizedBox(height: 4),
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

String _description(
  BuildContext context,
  CatalogueItem item,
  ResumeEntry? resume,
) => resume == null
    ? catalogueDescription(item, context: context)
    : resume.onDeck
    ? resume.pageCount > 0
          ? context.tr('0/{0} pages', [resume.pageCount])
          : context.tr('Up next')
    : !resume.raster && (resume.pageKnown || resume.totalProgression != null)
    ? context.tr('{0}% read', [(resume.progress * 100).round()])
    : resume.pageKnown
    ? context.tr('Page {0}/{1}', [resume.pageIndex + 1, resume.pageCount])
    : context.tr('In progress');
