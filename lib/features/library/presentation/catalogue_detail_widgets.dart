import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_metadata.dart';
import '../domain/resume_entry.dart';
import 'book_cover.dart';
import 'catalogue_presentation.dart';

class CatalogueDetailHeader extends StatelessWidget {
  const CatalogueDetailHeader({
    super.key,
    required this.item,
    required this.actions,
    required this.metadata,
    required this.details,
    this.resume,
  });
  final CatalogueItem item;
  final CatalogueMetadata metadata;
  final ResumeEntry? resume;
  final Widget actions, details;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final wide = constraints.maxWidth >= 640;
      final stacked = constraints.maxWidth < 280 || scale > 1.5;
      final coverWidth = wide ? 180.0 : 104.0;
      final theme = Theme.of(context);
      final information = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              item.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: wide ? 30 : 24,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            catalogueDescription(item, context: context),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (metadata.status.isNotEmpty ||
              metadata.readingDirection.isNotEmpty ||
              metadata.ageRating != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (metadata.status.isNotEmpty)
                  _Label(context.tr(humanizeMetadata(metadata.status))),
                if (metadata.readingDirection.isNotEmpty)
                  _Label(
                    context.tr(
                      readingDirectionLabel(metadata.readingDirection),
                    ),
                  ),
                if (metadata.ageRating != null)
                  _Label('${metadata.ageRating}+'),
              ],
            ),
          ],
          if (resume != null && !resume!.onDeck) ...[
            const SizedBox(height: 12),
            LText(
              resume!.pageKnown ? 'Page {0}/{1}' : 'In progress',
              arguments: [resume!.pageIndex + 1, resume!.pageCount],
              style: theme.textTheme.bodySmall,
            ),
            if (resume!.pageKnown) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: resume!.progress,
                semanticsLabel: context.tr("Reading progress"),
                semanticsValue: '${(resume!.progress * 100).round()}%',
              ),
            ],
          ],
          if (wide && !stacked) ...[
            const SizedBox(height: 16),
            actions,
            details,
          ],
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stacked) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BookCover(item: item, width: coverWidth),
            ),
            const SizedBox(height: 16),
            information,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(item: item, width: coverWidth),
                SizedBox(width: wide ? 24 : 16),
                Expanded(child: information),
              ],
            ),
          if (!wide || stacked) ...[
            const SizedBox(height: 16),
            actions,
            details,
          ],
        ],
      );
    },
  );
}

class CatalogueSummary extends StatefulWidget {
  const CatalogueSummary({super.key, required this.summary});
  final String summary;
  @override
  State<CatalogueSummary> createState() => _CatalogueSummaryState();
}

class _CatalogueSummaryState extends State<CatalogueSummary> {
  bool _expanded = false;
  @override
  void didUpdateWidget(CatalogueSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        final painter = TextPainter(
          text: TextSpan(text: widget.summary, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              'Synopsis',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (_expanded)
              SelectableText(widget.summary, style: style)
            else
              Text(
                widget.summary,
                style: style,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (overflow)
              TextButton.icon(
                key: const Key('detail-summary-toggle'),
                onPressed: () {
                  setState(() => _expanded = !_expanded);
                  if (!_expanded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Scrollable.ensureVisible(context, alignment: 0);
                      }
                    });
                  }
                },
                icon: Icon(
                  _expanded ? InkIcons.caretUp : InkIcons.caretDown,
                  size: 16,
                ),
                label: LText(_expanded ? 'Show less' : 'Show more'),
              ),
          ],
        );
      },
    ),
  );
}

class CatalogueMetadataSection extends StatelessWidget {
  const CatalogueMetadataSection({
    super.key,
    required this.metadata,
    this.complete = false,
  });
  final CatalogueMetadata metadata;
  final bool complete;

  bool get _hasDetails =>
      metadata.authors.isNotEmpty ||
      metadata.publisher.isNotEmpty ||
      metadata.language.isNotEmpty ||
      metadata.links.isNotEmpty ||
      metadata.releaseDate.isNotEmpty ||
      metadata.isbn.isNotEmpty ||
      metadata.genres.isNotEmpty ||
      metadata.tags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasDetails) return const SizedBox.shrink();
    final roles = <String, List<String>>{};
    for (final author in metadata.authors) {
      roles.putIfAbsent(author.role, () => []).add(author.name);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.genres.isNotEmpty)
          _MetadataRow(
            label: context.tr("Genres"),
            values: complete
                ? metadata.genres
                : metadata.genres.take(6).toList(),
          ),
        if (metadata.tags.isNotEmpty)
          _MetadataRow(
            label: context.tr("Tags"),
            values: complete ? metadata.tags : metadata.tags.take(6).toList(),
          ),
        if (complete) ...[
          for (final role in roles.entries)
            _MetadataRow(
              label: role.key.isEmpty ? 'Authors' : humanizeMetadata(role.key),
              values: role.value,
            ),
          if (metadata.publisher.isNotEmpty)
            _MetadataRow(
              label: context.tr("Publisher"),
              values: [metadata.publisher],
            ),
          if (metadata.language.isNotEmpty)
            _MetadataRow(
              label: context.tr("Language"),
              values: [metadata.language],
            ),
          if (metadata.releaseDate.isNotEmpty)
            _MetadataRow(
              label: context.tr("Release date"),
              values: [metadata.releaseDate],
            ),
          if (metadata.isbn.isNotEmpty)
            _MetadataRow(label: context.tr("ISBN"), values: [metadata.isbn]),
          if (metadata.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            LText('Links', style: Theme.of(context).textTheme.titleSmall),
            for (final link in metadata.links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  link.label.isEmpty ? context.tr('Reference') : link.label,
                ),
                subtitle: SelectableText(link.url),
                trailing: IconButton(
                  tooltip: context.tr("Copy link"),
                  icon: const Icon(InkIcons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link.url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: LText('Link copied')),
                      );
                    }
                  },
                ),
              ),
          ],
        ] else ...[
          if (metadata.authors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                metadata.authors
                    .map((author) => author.name)
                    .toSet()
                    .take(3)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (metadata.publisher.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                metadata.publisher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          TextButton.icon(
            key: const Key('detail-metadata'),
            onPressed: () => showInkSheet<void>(
              context: context,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      'Publication details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    CatalogueMetadataSection(
                      metadata: metadata,
                      complete: true,
                    ),
                  ],
                ),
              ),
            ),
            icon: const Icon(InkIcons.info, size: 18),
            label: LText(
              metadata.genres.length > 6 || metadata.tags.length > 6
                  ? 'All tags and publication details'
                  : 'Publication details',
            ),
          ),
        ],
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.values});
  final String label;
  final List<String> values;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LText(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final value in values) _Label(value)],
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: InkoraColors.of(context).raised,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}

String humanizeMetadata(String value) {
  final words = value.toLowerCase().replaceAll('_', ' ');
  return words.isEmpty
      ? words
      : '${words[0].toUpperCase()}${words.substring(1)}';
}

String readingDirectionLabel(String value) => switch (value.toUpperCase()) {
  'LEFT_TO_RIGHT' => 'Left to right',
  'RIGHT_TO_LEFT' => 'Right to left',
  'VERTICAL' => 'Vertical',
  'WEBTOON' => 'Webtoon',
  _ => humanizeMetadata(value),
};
