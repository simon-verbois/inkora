import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/ui_preferences_provider.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_metadata.dart';
import 'catalogue_presentation.dart';
import 'catalogue_link_button.dart';

/// Lighter hero of library, collection and reading-list pages: kind icon,
/// title, member count and synopsis, matching the series hero layout.
class GroupHero extends StatelessWidget {
  const GroupHero({super.key, required this.item});
  final CatalogueItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = InkoraColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpace.lg,
        InkSpace.sm,
        InkSpace.lg,
        InkSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: InkRadius.medium,
                ),
                child: SizedBox.square(
                  dimension: 64,
                  child: Icon(
                    catalogueIcon(item.kind),
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: InkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        item.title,
                        style: theme.textTheme.screenTitle?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: InkSpace.xs),
                    Text(
                      catalogueDescription(item, context: context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: InkSpace.lg),
            CatalogueSummary(key: ValueKey(item.id), summary: item.summary),
          ],
        ],
      ),
    );
  }
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
            LText('Synopsis', style: Theme.of(context).textTheme.sectionTitle),
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
                  if (_expanded) {
                    // Do not reposition a synopsis that is already visible.
                    Scrollable.ensureVisible(
                      context,
                      alignmentPolicy:
                          ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                    );
                  }
                  setState(() => _expanded = !_expanded);
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

class CatalogueMetadataSection extends ConsumerWidget {
  const CatalogueMetadataSection({
    super.key,
    required this.metadata,
    this.complete = false,
  });
  final CatalogueMetadata metadata;
  final bool complete;

  bool _hasDetails(bool hideTags) =>
      metadata.authors.isNotEmpty ||
      metadata.publisher.isNotEmpty ||
      metadata.language.isNotEmpty ||
      metadata.links.isNotEmpty ||
      metadata.releaseDate.isNotEmpty ||
      metadata.isbn.isNotEmpty ||
      metadata.genres.isNotEmpty ||
      (!hideTags && metadata.tags.isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideTags = ref.watch(
      uiPreferencesProvider.select(
        (value) => value.asData?.value.hideTags ?? true,
      ),
    );
    if (!_hasDetails(hideTags)) return const SizedBox.shrink();
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
        if (!hideTags && metadata.tags.isNotEmpty)
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
            CatalogueLinks(links: metadata.links),
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
            onPressed: () => showInkPopup<void>(
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
              !hideTags &&
                      (metadata.genres.length > 6 || metadata.tags.length > 6)
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
      borderRadius: InkRadius.small,
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
