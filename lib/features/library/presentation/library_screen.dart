import '../../settings/application/ui_preferences_provider.dart';
import '../../settings/domain/ui_preferences.dart';
import '../../../app/l10n/app_strings.dart';
import '../../../app/icons/inkora_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/inkora_widgets.dart';
import '../../../app/theme/inkora_theme.dart';
import '../application/catalogue_providers.dart';
import '../application/cover_providers.dart';
import '../application/discovery_providers.dart';
import '../domain/catalogue.dart';
import '../domain/discovery.dart';
import 'catalogue_card.dart';
import 'catalogue_widgets.dart';
import 'resume_carousel.dart';

/// The authenticated home hub. Shelves use the active account's local data.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  @visibleForTesting
  bool get pollingActive => _poll?.isActive ?? false;
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _updatePolling() {
    final active =
        _visible &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!active) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          GoRouter.of(context).routeInformationProvider.value.uri.path == '/') {
        unawaited(_refreshResume());
      }
    });
  }

  Future<void> _refreshResume({bool force = false}) async {
    try {
      final repository = await ref.read(resumeRepositoryProvider.future);
      if (!mounted) return;
      await repository?.refresh(force: force);
      if (!mounted) return;
      final covers = await ref.read(coverRepositoryProvider.future);
      await covers?.revalidateActive(onlyIfStale: !force);
    } catch (_) {
      // A foreground/navigation refresh may outlive logout or widget disposal.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) unawaited(_refreshResume());
    _visible = visible;
    _updatePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updatePolling();
    if (state == AppLifecycleState.resumed && _visible) {
      unawaited(_refreshResume(force: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Each section watches only its own provider: a reading-progress or
    // discovery emission must not rebuild (and re-measure) every shelf.
    return InkContent(
      child: RefreshIndicator(
        onRefresh: () => refreshCatalogue(ref),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.sizeOf(context).width >= InkoraLayout.railBreakpoint
                ? 8
                : 16,
            16,
            16,
          ),
          children: [
            const CatalogueRefreshStatus(),
            const _ResumeSection(),
            const SizedBox(height: 4),
            const _DiscoveryShelf(index: 0),
            const SizedBox(height: 4),
            const _RecentShelf(),
            for (
              var index = 1;
              index < DiscoveryPage.sectionCount;
              index++
            ) ...[const SizedBox(height: 4), _DiscoveryShelf(index: index)],
          ],
        ),
      ),
    );
  }
}

class _ResumeSection extends ConsumerWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref.watch(resumeEntriesProvider);
    return InkPanel(
      framed: false,
      title: context.tr("Continue reading"),
      child: resume.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => InkEmptyState(
          icon: InkIcons.clockCounterClockwise,
          title: context.tr("Reading history unavailable"),
          message: context.tr("Your saved books remain in Libraries."),
        ),
        data: (entries) => entries.isEmpty
            ? InkEmptyState(
                icon: InkIcons.bookOpen,
                title: context.tr("Your next great read"),
                message: context.tr(
                  "Open a book to start your reading journey.",
                ),
                action: () => context.go('/libraries'),
                label: context.tr("Explore libraries"),
              )
            : ResumeCarousel(
                entries: entries,
                density:
                    ref.watch(
                      uiPreferencesProvider.select(
                        (p) => p.asData?.value.density,
                      ),
                    ) ??
                    CatalogueDensity.comfortable,
                onViewAll: () => context.go('/libraries'),
              ),
      ),
    );
  }
}

class _RecentShelf extends ConsumerWidget {
  const _RecentShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _HomeShelf(
    title: context.tr("Recently updated"),
    data: ref.watch(
      cataloguePageProvider(
        const CatalogueQuery(
          kind: CatalogueKind.series,
          readingUnits: true,
          sort: CatalogueSort.recentlyUpdated,
          pageSize: CatalogueShelf.maxItems,
          showUnavailable: false,
        ),
      ),
    ),
    actionLabel: context.tr("Recently updated"),
    onAction: () => context.push('/catalogue/series?sort=recentlyUpdated'),
  );
}

class _DiscoveryShelf extends ConsumerWidget {
  const _DiscoveryShelf({required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref
        .watch(discoverySectionsProvider)
        .whenData((pages) => pages[index]);
    final label =
        data.asData?.value.label ??
        (index == 1 ? 'From your libraries' : 'More to explore');
    return _HomeShelf(
      key: ValueKey(index == 0 ? 'home-discovery' : 'home-discovery-$index'),
      title: index == 0
          ? (data.asData == null
                ? 'Discover'
                : context.tr('Discover · {0}', [context.tr(label)]))
          : label,
      data: data.whenData(
        (page) => LocalCataloguePage(page.items, page.items.length, null),
      ),
      actionLabel: switch (index) {
        0 => 'Browse all books',
        1 => 'Browse libraries',
        _ => 'Explore your libraries',
      },
      shelfIdentity: data.asData?.value.items
          .map((item) => item.identity)
          .join('|'),
      emptyTitle: context.tr("Nothing new to suggest"),
      emptyMessage: context.tr(
        "Refresh your catalogue to bring your books here.",
      ),
      onAction: () => context.go('/libraries'),
    );
  }
}

class _HomeShelf extends ConsumerWidget {
  const _HomeShelf({
    super.key,
    required this.title,
    required this.data,
    required this.onAction,
    required this.actionLabel,
    this.emptyTitle = 'Your shelves are waiting',
    this.emptyMessage = 'Refresh your catalogue to bring your books here.',
    this.shelfIdentity,
  });
  final String title, actionLabel, emptyTitle, emptyMessage;
  final AsyncValue<LocalCataloguePage> data;
  final VoidCallback onAction;
  final Object? shelfIdentity;
  @override
  Widget build(BuildContext context, WidgetRef ref) => InkPanel(
    framed: false,
    title: title,
    child: data.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) =>
          const LText('Saved catalogue unavailable. Try refreshing.'),
      data: (page) => page.items.isEmpty
          ? InkEmptyState(
              icon: InkIcons.bookOpen,
              title: emptyTitle,
              message: emptyMessage,
            )
          : CatalogueShelf(
              key: shelfIdentity == null ? null : ValueKey(shelfIdentity),
              items: page.items,
              density:
                  ref.watch(
                    uiPreferencesProvider.select(
                      (p) => p.asData?.value.density,
                    ),
                  ) ??
                  CatalogueDensity.comfortable,
              onViewAll: onAction,
              viewAllLabel: actionLabel,
            ),
    ),
  );
}
