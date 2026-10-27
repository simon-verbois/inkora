import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../application/catalogue_providers.dart';
import '../application/cover_providers.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_metadata.dart';
import '../domain/resume_entry.dart';
import '../domain/volume_progress.dart';
import '../../settings/application/ui_preferences_provider.dart';
import 'book_cover.dart';
import 'catalogue_detail_widgets.dart';
import 'catalogue_link_button.dart';
import 'catalogue_presentation.dart';
import 'progress_format.dart';

/// Source key of a Komga series status. The status chip is always shown.
String seriesStatusLabel(String status) => switch (status.toUpperCase()) {
  'ENDED' => 'Ended',
  'ONGOING' => 'Ongoing',
  'ABANDONED' => 'Abandoned',
  'HIATUS' => 'Hiatus',
  '' => 'Status unknown',
  _ => humanizeMetadata(status),
};

/// Display name of a volume, using the server title before numbering.
String volumeName(AppStrings strings, SeriesVolume volume) =>
    volumeDisplayName(strings, volume.title, volume.number) ?? '';

/// The series' Continue reading entries: the in-progress one (`reading`) and
/// the server's next volume (`next`, On Deck).
({ResumeEntry? reading, ResumeEntry? next}) seriesResume(
  List<ResumeEntry> entries,
  String seriesId,
) {
  ResumeEntry? reading, next;
  for (final entry in entries) {
    if (!entry.item.canOpen || entry.item.seriesId != seriesId) continue;
    if (entry.onDeck) {
      next ??= entry;
    } else {
      reading ??= entry;
    }
  }
  return (reading: reading, next: next);
}

/// Book ids of the series' resume entries; a value (record) so widgets
/// rebuild only when the series' own choice changes, not on page saves.
final seriesResumeIdsProvider = Provider.autoDispose
    .family<({String? reading, String? next}), String>(
      (ref, seriesId) => ref.watch(
        resumeEntriesProvider.select((state) {
          final resume = seriesResume(
            state.asData?.value ?? const [],
            seriesId,
          );
          return (reading: resume.reading?.item.id, next: resume.next?.item.id);
        }),
      ),
    );

/// The volume a series continues with, or null when the series is finished.
SeriesVolume? currentVolume(
  SeriesProgress progress,
  ({String? reading, String? next}) resume,
) {
  final index = progress.currentIndex(
    resumeBookId: resume.reading,
    nextBookId: resume.next,
  );
  return index == null ? null : progress.volumes[index];
}

/// Blurred cover behind the compact page or wide information pane. One instance
/// stays outside the scrolling content: artwork is decoded at 32 px and blurred
/// inside a RepaintBoundary, without sampling the screen with a BackdropFilter.
/// A gradient fades it
/// into the page background, which is also the floating header band's color.
class SeriesBackdrop extends ConsumerWidget {
  const SeriesBackdrop({super.key, required this.item});
  final CatalogueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final repository = item.canOpen
        ? ref.watch(coverRepositoryProvider).asData?.value
        : null;
    final key = (kind: item.kind.name, id: item.id, modified: item.modified);
    final bytes = repository == null
        ? null
        : ref.watch(coverProvider(key)).asData?.value ?? repository.peek(key);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Image(
                    key: const Key('series-backdrop'),
                    image: coverImage(repository!, key, bytes, 32, 1),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .5, 1],
                    colors: [
                      background.withValues(alpha: .55),
                      background.withValues(alpha: .72),
                      background,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover, title, credits and exactly two chips: book count and status.
class SeriesHero extends StatelessWidget {
  const SeriesHero({
    super.key,
    required this.item,
    required this.volumeCount,
    this.coverWidth = 112,
    this.topInset = 0,
    this.showBackdrop = true,
  });
  final CatalogueItem item;
  final int volumeCount;
  final double coverWidth;

  /// Space inside the backdrop for an overlaying Back button and status bar.
  final double topInset;
  final bool showBackdrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = item.metadata;
    final authors = metadata.authors.map((author) => author.name).toSet();
    final colors = InkoraColors.of(context);
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            item.title,
            key: const Key('series-title'),
            style: theme.textTheme.screenTitle?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        if (authors.isNotEmpty) ...[
          const SizedBox(height: InkSpace.xs),
          Text(
            authors.join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: InkSpace.sm),
        Wrap(
          spacing: InkSpace.xs + 2,
          runSpacing: InkSpace.xs + 2,
          children: [
            _HeroChip(
              key: const Key('series-count'),
              label: AppStrings.of(context).quantity(volumeCount, 'book'),
            ),
            _HeroChip(
              key: const Key('series-status'),
              label: context.tr(seriesStatusLabel(metadata.status)),
              color: colors.success,
              dot: true,
            ),
          ],
        ),
      ],
    );
    return Stack(
      children: [
        if (showBackdrop) Positioned.fill(child: SeriesBackdrop(item: item)),
        Padding(
          padding: EdgeInsets.fromLTRB(
            InkSpace.lg,
            topInset + InkSpace.sm,
            InkSpace.lg,
            InkSpace.lg,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5;
              final cover = BookCover(item: item, width: coverWidth);
              return stacked
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
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    super.key,
    required this.label,
    this.color,
    this.dot = false,
  });
  final String label;
  final Color? color;
  final bool dot;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: InkoraColors.of(context).raised.withValues(alpha: .85),
      borderRadius: InkRadius.small,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpace.sm,
        vertical: InkSpace.xs - 1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: InkSpace.xs + 2),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Primary reading action with the book title and the batch-download button.
class SeriesReadAction extends ConsumerWidget {
  const SeriesReadAction({
    super.key,
    required this.seriesId,
    required this.onDownload,
    this.onMark,
  });
  final String seriesId;
  final VoidCallback onDownload;
  final VoidCallback? onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    // Resume entries change on every saved page; select only this series'
    // entries so the button rebuilds when its own label changes.
    final resume = ref.watch(
      resumeEntriesProvider.select(
        (state) => seriesResume(state.asData?.value ?? const [], seriesId),
      ),
    );
    final progress = ref.watch(seriesProgressProvider(seriesId)).asData?.value;
    CatalogueItem? target;
    String? label;
    final reading = resume.reading;
    final current = progress == null
        ? null
        : currentVolume(progress, (
            reading: reading?.item.id,
            next: resume.next?.item.id,
          ));
    if (reading != null && (current == null || current.id == reading.item.id)) {
      target = reading.item;
      label =
          volumeDisplayName(strings, reading.item.title, reading.item.number) ??
          '';
    } else if (current != null) {
      target = current.item;
      label = volumeName(strings, current);
    } else if (progress != null) {
      final first = progress.volumes.where((v) => v.available).firstOrNull;
      if (first != null) {
        target = first.item;
        label = volumeName(strings, first);
      }
    } else if (resume.next != null) {
      target = resume.next!.item;
      label =
          volumeDisplayName(
            strings,
            resume.next!.item.title,
            resume.next!.item.number,
          ) ??
          '';
    }
    return Row(
      children: [
        Expanded(
          child: target == null
              ? const SizedBox.shrink()
              : FilledButton.icon(
                  key: const Key('detail-read'),
                  onPressed: () => openBookReader(context, target!),
                  icon: const Icon(InkIcons.play, size: 20),
                  label: Text(
                    strings.text(
                      (target.id == reading?.item.id ||
                              progress?.of(target.id).reading == true)
                          ? 'Resume - {0}'
                          : 'Start - {0}',
                      [label!],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
        const SizedBox(width: InkSpace.sm),
        IconButton.outlined(
          key: const Key('detail-mark'),
          tooltip: strings.text('Reading progress'),
          onPressed: onMark,
          icon: const Icon(InkIcons.listChecks),
        ),
        const SizedBox(width: InkSpace.sm),
        IconButton.outlined(
          key: const Key('detail-download'),
          tooltip: strings.text('Download volumes'),
          onPressed: onDownload,
          icon: const Icon(InkIcons.downloadSimple),
        ),
      ],
    );
  }
}

/// "About" content: synopsis with a fade and Read more, tappable genres
/// (opening the catalogue filtered by genre), tags and publication facts.
class SeriesAbout extends ConsumerWidget {
  const SeriesAbout({super.key, required this.item});
  final CatalogueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideTags = ref.watch(
      uiPreferencesProvider.select(
        (value) => value.asData?.value.hideTags ?? true,
      ),
    );
    final metadata = item.metadata;
    final theme = Theme.of(context);
    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(top: InkSpace.xl, bottom: InkSpace.sm),
      child: Semantics(
        header: true,
        child: LText(label, style: theme.textTheme.sectionTitle),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.summary.isNotEmpty)
          SeriesSynopsis(key: ValueKey(item.id), summary: item.summary),
        if (metadata.genres.isNotEmpty) ...[
          section('Genres'),
          Wrap(
            spacing: InkSpace.sm,
            runSpacing: InkSpace.xs,
            children: [
              for (final genre in metadata.genres)
                ActionChip(
                  key: ValueKey('genre-$genre'),
                  label: Text(genre),
                  onPressed: () => context.pushNamed(
                    'catalogue',
                    pathParameters: {'kind': CatalogueKind.series.name},
                    queryParameters: {'genre': genre},
                  ),
                ),
            ],
          ),
        ],
        if (!hideTags && metadata.tags.isNotEmpty) ...[
          section('Tags'),
          Wrap(
            spacing: InkSpace.xs + 2,
            runSpacing: InkSpace.xs + 2,
            children: [for (final tag in metadata.tags) _HeroChip(label: tag)],
          ),
        ],
        section('Publication details'),
        SeriesFacts(metadata: metadata),
      ],
    );
  }
}

/// Collapsible synopsis: text alpha fades across the last three lines, then
/// Read more / Show less. Overflow is measured once per width/text scale.
class SeriesSynopsis extends StatefulWidget {
  const SeriesSynopsis({super.key, required this.summary});
  final String summary;
  static const lines = 6;
  static const portraitLines = 8;
  @override
  State<SeriesSynopsis> createState() => _SeriesSynopsisState();
}

class _SeriesSynopsisState extends State<SeriesSynopsis> {
  bool _expanded = false;
  ({
    double width,
    double scale,
    int lines,
    TextStyle? style,
    String text,
    bool overflow,
  })?
  _measured;

  bool _overflows(double width, TextStyle? style) {
    final window = MediaQuery.sizeOf(context);
    final lines = window.width <= window.height
        ? SeriesSynopsis.portraitLines
        : SeriesSynopsis.lines;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final cached = _measured;
    if (cached != null &&
        cached.width == width &&
        cached.scale == scale &&
        cached.lines == lines &&
        cached.style == style &&
        cached.text == widget.summary) {
      return cached.overflow;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.summary, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: lines,
    )..layout(maxWidth: width);
    final overflow = painter.didExceedMaxLines;
    painter.dispose();
    _measured = (
      width: width,
      scale: scale,
      lines: lines,
      style: style,
      text: widget.summary,
      overflow: overflow,
    );
    return overflow;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflow = _overflows(constraints.maxWidth, style);
        final collapsed = Text(
          widget.summary,
          key: const Key('series-synopsis'),
          style: style,
          maxLines: _measured!.lines,
          overflow: TextOverflow.clip,
        );
        final fadeStart = (_measured!.lines - 3) / _measured!.lines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_expanded)
              SelectableText(widget.summary, style: style)
            else if (overflow)
              // One cached detail header, outside list/grid items or reader pages.
              RepaintBoundary(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, fadeStart, (fadeStart + 1) / 2, 1],
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Color(0x66FFFFFF),
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  child: collapsed,
                ),
              )
            else
              collapsed,
            if (overflow)
              TextButton(
                key: const Key('detail-summary-toggle'),
                onPressed: () {
                  if (_expanded) {
                    // Keep a visible synopsis in place. Only reveal its start
                    // when it has scrolled above the pane before shrinking.
                    Scrollable.ensureVisible(
                      context,
                      alignmentPolicy:
                          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                    );
                  }
                  setState(() => _expanded = !_expanded);
                },
                child: LText(_expanded ? 'Show less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}

/// Publication facts as label/value rows; credits keep server names and
/// localize only known roles.
class SeriesFacts extends StatelessWidget {
  const SeriesFacts({super.key, required this.metadata});
  final CatalogueMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final roles = <String, List<String>>{};
    for (final author in metadata.authors) {
      roles.putIfAbsent(author.role, () => []).add(author.name);
    }
    final facts = <(String, String, bool)>[
      for (final role in roles.entries)
        (
          role.key.isEmpty ? 'Authors' : humanizeMetadata(role.key),
          role.value.join(', '),
          false,
        ),
      if (metadata.publisher.isNotEmpty)
        ('Publisher', metadata.publisher, false),
      if (metadata.releaseDate.isNotEmpty)
        ('Release date', metadata.releaseDate, false),
      if (metadata.language.isNotEmpty) ('Language', metadata.language, false),
      if (metadata.isbn.isNotEmpty) ('ISBN', metadata.isbn, false),
    ];
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 320 * scale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value, translated) in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: InkSpace.sm),
                child: MergeSemantics(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(label, style: labelStyle),
                            translated
                                ? LText(value, style: valueStyle)
                                : Text(value, style: valueStyle),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120 * scale.clamp(1, 1.4),
                              child: LText(label, style: labelStyle),
                            ),
                            const SizedBox(width: InkSpace.md),
                            Expanded(
                              child: translated
                                  ? LText(value, style: valueStyle)
                                  : Text(value, style: valueStyle),
                            ),
                          ],
                        ),
                ),
              ),
            CatalogueLinks(links: metadata.links),
          ],
        );
      },
    );
  }
}
