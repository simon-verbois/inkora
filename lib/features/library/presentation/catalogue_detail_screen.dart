import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
import 'catalogue_detail_widgets.dart';
import 'catalogue_widgets.dart';
import 'volume_list_tile.dart';
import 'volume_list.dart';
import '../../../offline/presentation/batch_download_sheet.dart';

class CatalogueDetailScreen extends ConsumerStatefulWidget {
  const CatalogueDetailScreen({
    required this.kind,
    required this.id,
    super.key,
  });
  final CatalogueKind kind;
  final String id;
  @override
  ConsumerState<CatalogueDetailScreen> createState() =>
      _CatalogueDetailScreenState();
}

class _CatalogueDetailScreenState extends ConsumerState<CatalogueDetailScreen> {
  final _scroll = ScrollController();
  CatalogueQuery get _volumes => CatalogueQuery(
    kind: CatalogueKind.book,
    seriesId: widget.id,
    sort: CatalogueSort.sequence,
  );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_more);
  }

  @override
  void didUpdateWidget(CatalogueDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.id != widget.id || oldWidget.kind != widget.kind) &&
        _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _more() {
    if (widget.kind != CatalogueKind.series ||
        !_scroll.hasClients ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension * 2) {
      ref.read(catalogueFeedProvider(_volumes)).asData?.value?.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _browse(CatalogueKind target, Map<String, String> query) =>
      context.pushNamed(
        'catalogue',
        pathParameters: {'kind': target.name},
        queryParameters: query,
      );

  void _open(CatalogueItem book) => openCatalogueItem(context, book);

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final id = widget.id;
    final data = ref.watch(catalogueItemProvider((kind, id)));
    // The details screen stays mounted under the reader. Rebuild only when
    // this series' resume choice changes, not on every saved page turn.
    ref.watch(
      resumeEntriesProvider.select(
        (state) => [
          for (final entry in state.asData?.value ?? const <ResumeEntry>[])
            if (entry.item.seriesId == id)
              '${entry.item.id}:${entry.onDeck}:${entry.raster}:${entry.item.canOpen}',
        ].join('|'),
      ),
    );
    final entries =
        ref.read(resumeEntriesProvider).asData?.value ?? const <ResumeEntry>[];
    final volumes = kind == CatalogueKind.series
        ? ref.watch(catalogueFeedStateProvider(_volumes))
        : null;
    if (kind == CatalogueKind.series) {
      ref.listen(catalogueFeedStateProvider(_volumes), (_, next) {
        if (next.asData?.value.loading == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _more();
          });
        }
      });
    }
    final books = volumes?.asData?.value.page.items ?? const <CatalogueItem>[];
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: InkContent(
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => InkEmptyState(
                  icon: InkIcons.warningCircle,
                  title: context.tr("Details unavailable"),
                  message: context.tr("Unable to open saved details."),
                  action: () =>
                      ref.invalidate(catalogueItemProvider((kind, id))),
                  label: context.tr("Retry"),
                ),
                data: (item) {
                  if (item == null) {
                    return InkEmptyState(
                      icon: InkIcons.bookOpen,
                      title: context.tr("Item unavailable"),
                      message: context.tr(
                        "This item is not in the saved catalogue.",
                      ),
                    );
                  }
                  final metadata = item.metadata;
                  final eligible = entries.where(
                    (entry) => entry.item.canOpen && entry.item.seriesId == id,
                  );
                  final resume =
                      eligible.where((entry) => !entry.onDeck).firstOrNull ??
                      eligible.firstOrNull;
                  final nextBook =
                      resume?.item ??
                      books.where((book) => book.canOpen).firstOrNull;
                  final actions = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (item.canOpen &&
                            kind == CatalogueKind.series &&
                            nextBook != null)
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('detail-read'),
                                  onPressed: () => _open(nextBook),
                                  icon: const Icon(InkIcons.play, size: 20),
                                  label: LText(
                                    resume == null || resume.onDeck
                                        ? 'Start reading - {0}'
                                        : 'Continue reading - {0}',
                                    arguments: [nextBook.title],
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (item.canOpen && kind == CatalogueKind.series)
                          TextButton.icon(
                            onPressed: () => showInkSheet<void>(
                              context: context,
                              child: BatchDownloadSheet(seriesId: id),
                            ),
                            icon: const Icon(InkIcons.downloadSimple),
                            label: const LText('Download volumes'),
                          ),
                        if (item.canOpen && kind == CatalogueKind.library)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _browse(CatalogueKind.series, {
                                  'library': id,
                                }),
                                icon: const Icon(InkIcons.list),
                                label: const LText('Browse all books'),
                              ),
                            ],
                          ),
                        if (item.canOpen &&
                            (kind == CatalogueKind.collection ||
                                kind == CatalogueKind.readlist))
                          FilledButton(
                            onPressed: () => _browse(
                              kind == CatalogueKind.collection
                                  ? CatalogueKind.series
                                  : CatalogueKind.book,
                              {
                                'groupKind': kind.name,
                                'group': id,
                                'ordered': item.ordered.toString(),
                              },
                            ),
                            child: LText(
                              kind == CatalogueKind.collection
                                  ? 'Browse all books'
                                  : 'Browse reading list',
                            ),
                          ),
                      ],
                    ),
                  );
                  return CustomScrollView(
                    key: ValueKey('detail-$kind-$id'),
                    controller: _scroll,
                    scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            kind == CatalogueKind.series
                                ? 64 + MediaQuery.paddingOf(context).top
                                : 8,
                            16,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CatalogueRefreshStatus(),
                              CatalogueDetailHeader(
                                item: item,
                                metadata: metadata,
                                resume: resume,
                                actions: actions,
                                details: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.summary.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      CatalogueSummary(
                                        key: ValueKey(item.id),
                                        summary: item.summary,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    CatalogueMetadataSection(
                                      metadata: metadata,
                                    ),
                                  ],
                                ),
                              ),
                              if (!item.canOpen)
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: LText(
                                    'Unavailable or removed. Saved metadata is retained.',
                                  ),
                                ),
                              if (kind == CatalogueKind.series && item.canOpen)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 12,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: LText(
                                          'Volumes and chapters',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (kind == CatalogueKind.series && item.canOpen) ...[
                        if (books.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            sliver: VolumeList(
                              itemCount: books.length,
                              itemBuilder: (_, index) =>
                                  VolumeListTile(item: books[index]),
                            ),
                          )
                        else if (volumes?.isLoading == true ||
                            volumes?.asData?.value.loading == true)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            ),
                          )
                        else if (volumes?.hasError != true &&
                            volumes?.asData?.value.error != true)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: LText('No saved books in this series.'),
                            ),
                          ),
                        if (volumes?.hasError == true ||
                            volumes?.asData?.value.error == true)
                          SliverToBoxAdapter(
                            child: InkEmptyState(
                              icon: InkIcons.warningCircle,
                              title: context.tr("Saved volumes unavailable"),
                              message: context.tr(
                                "Unable to load this series’ saved volumes.",
                              ),
                              action: () => ref
                                  .read(catalogueFeedProvider(_volumes))
                                  .asData
                                  ?.value
                                  ?.retry(),
                              label: context.tr("Retry"),
                            ),
                          ),
                        if (volumes?.asData?.value.hasMore == true)
                          SliverToBoxAdapter(
                            child: Center(
                              child: TextButton(
                                onPressed: () => ref
                                    .read(catalogueFeedProvider(_volumes))
                                    .asData
                                    ?.value
                                    ?.loadMore(),
                                child: const LText('Load more volumes'),
                              ),
                            ),
                          ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              ),
            ),
          ),
          if (kind == CatalogueKind.series)
            Positioned(
              top: 8,
              left: 16,
              child: SafeArea(
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    key: const Key('series-back'),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(InkIcons.caretLeft, size: 22),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
