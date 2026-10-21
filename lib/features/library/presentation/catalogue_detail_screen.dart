import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons/inkora_icons.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/theme/inkora_theme.dart';
import '../../../app/widgets/ink_screen_header.dart';
import '../../../app/widgets/inkora_widgets.dart';
import '../application/catalogue_providers.dart';
import '../domain/catalogue.dart';
import 'catalogue_card.dart';
import 'catalogue_detail_widgets.dart';
import 'catalogue_grid.dart';
import 'catalogue_widgets.dart';
import 'series_detail_screen.dart';

/// Detail page of a catalogue item. Series use [SeriesDetailScreen]; library,
/// collection and reading-list pages share its structure: floating Back
/// bubble, a lighter hero, the primary Browse action and a cover grid.
class CatalogueDetailScreen extends StatelessWidget {
  const CatalogueDetailScreen({
    required this.kind,
    required this.id,
    super.key,
  });
  final CatalogueKind kind;
  final String id;

  @override
  Widget build(BuildContext context) => kind == CatalogueKind.series
      ? SeriesDetailScreen(id: id)
      : GroupDetailScreen(kind: kind, id: id);
}

/// Library, collection and reading-list details.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.kind, required this.id, super.key});
  final CatalogueKind kind;
  final String id;
  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _scroll = ScrollController();

  /// Members shown in the grid: a library's series (with ebooks as reading
  /// units, like the catalogue), a collection's series, a list's books.
  CatalogueQuery _members(CatalogueItem item) => switch (widget.kind) {
    CatalogueKind.library => CatalogueQuery(
      kind: CatalogueKind.series,
      readingUnits: true,
      libraryId: widget.id,
    ),
    CatalogueKind.collection => CatalogueQuery(
      kind: CatalogueKind.series,
      readingUnits: true,
      groupKind: CatalogueKind.collection,
      groupId: widget.id,
      sort: item.ordered ? CatalogueSort.sequence : CatalogueSort.title,
    ),
    _ => CatalogueQuery(
      kind: CatalogueKind.book,
      groupKind: CatalogueKind.readlist,
      groupId: widget.id,
      sort: item.ordered ? CatalogueSort.sequence : CatalogueSort.title,
    ),
  };

  CatalogueQuery? _query;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_more);
  }

  @override
  void didUpdateWidget(GroupDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.id != widget.id || oldWidget.kind != widget.kind) &&
        _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _more() {
    final query = _query;
    if (query == null ||
        !_scroll.hasClients ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension * 2) {
      ref.read(catalogueFeedProvider(query)).asData?.value?.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _browse(CatalogueItem item) => context.pushNamed(
    'catalogue',
    pathParameters: {
      'kind': widget.kind == CatalogueKind.readlist
          ? CatalogueKind.book.name
          : CatalogueKind.series.name,
    },
    queryParameters: widget.kind == CatalogueKind.library
        ? {'library': widget.id}
        : {
            'groupKind': widget.kind.name,
            'group': widget.id,
            'ordered': item.ordered.toString(),
          },
  );

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final id = widget.id;
    final data = ref.watch(catalogueItemProvider((kind, id)));
    final item = data.asData?.value;
    final query = item == null ? null : _members(item);
    _query = query;
    final feed = query == null
        ? null
        : ref.watch(catalogueFeedStateProvider(query));
    if (query != null) {
      ref.listen(catalogueFeedStateProvider(query), (_, next) {
        if (next.asData?.value.loading == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _more();
          });
        }
      });
    }

    final members = feed?.asData?.value.page.items ?? const <CatalogueItem>[];
    return Scaffold(
      body: InkFloatingHeader(
        title: item == null ? null : Text(item.title),
        body: SafeArea(
          top: false,
          bottom: false,
          child: InkContent(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => InkEmptyState(
                icon: InkIcons.warningCircle,
                title: 'Details unavailable',
                message: 'Unable to open saved details.',
                action: () => ref.invalidate(catalogueItemProvider((kind, id))),
                label: 'Retry',
              ),
              data: (item) {
                if (item == null) {
                  return const InkEmptyState(
                    icon: InkIcons.bookOpen,
                    title: 'Item unavailable',
                    message: 'This item is not in the saved catalogue.',
                  );
                }
                final memberKind = kind == CatalogueKind.readlist
                    ? CatalogueKind.book
                    : CatalogueKind.series;
                final state = feed?.asData?.value;
                return CustomScrollView(
                  key: ValueKey('detail-$kind-$id'),
                  controller: _scroll,
                  scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CatalogueRefreshStatus(),
                          GroupHero(item: item),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: InkSpace.lg,
                            ),
                            child: item.canOpen
                                ? Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 600,
                                      ),
                                      child: FilledButton.icon(
                                        key: const Key('detail-browse'),
                                        onPressed: () => _browse(item),
                                        icon: const Icon(InkIcons.list),
                                        label: LText(
                                          kind == CatalogueKind.readlist
                                              ? 'Browse reading list'
                                              : 'Browse all books',
                                        ),
                                      ),
                                    ),
                                  )
                                : const LText(
                                    'Unavailable or removed. Saved metadata is retained.',
                                  ),
                          ),
                          if (item.canOpen)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                InkSpace.lg,
                                InkSpace.xl,
                                InkSpace.lg,
                                0,
                              ),
                              child: Semantics(
                                header: true,
                                child: LText(
                                  catalogueLabel(memberKind),
                                  style: Theme.of(context)
                                      .textTheme
                                      .sectionTitle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.canOpen)
                      if (members.isNotEmpty)
                        CatalogueGrid(
                          key: const Key('detail-grid'),
                          itemCount: members.length,
                          artwork: members,
                          itemBuilder: (_, index) =>
                              InkCoverTile(item: members[index]),
                        )
                      else if (feed?.isLoading == true ||
                          state?.loading == true)
                        CatalogueGrid(
                          key: const Key('detail-grid-skeleton'),
                          itemCount: 6,
                          itemBuilder: coverSkeletonBuilder,
                        )
                      else
                        SliverToBoxAdapter(
                          child: InkEmptyState(
                            icon: feed?.hasError == true || state?.error == true
                                ? InkIcons.cloudSlash
                                : InkIcons.magnifyingGlassMinus,
                            title:
                                feed?.hasError == true || state?.error == true
                                ? 'Catalogue unavailable'
                                : 'Nothing here yet',
                          ),
                        ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: InkSpace.xl),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
