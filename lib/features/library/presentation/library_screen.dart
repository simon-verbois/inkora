import '../../../app/icons/inkora_icons.dart';
import '../../settings/application/ui_preferences_provider.dart';
import '../../settings/domain/ui_preferences.dart';
import '../../../app/l10n/app_strings.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/inkora_widgets.dart';
import '../application/catalogue_providers.dart';
import '../application/cover_providers.dart';
import '../domain/catalogue.dart';
import 'resume_carousel.dart';
import 'catalogue_screen.dart';

/// The library catalogue is the home destination, with saved reading above it.
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
    return const CatalogueScreen(
      kind: CatalogueKind.series,
      embedded: true,
      header: _ResumeSection(),
      headerActions: [
        _HomeAction(
          destination: 'settings',
          label: 'Settings',
          icon: InkIcons.gearSix,
        ),
        _HomeAction(
          destination: 'downloads',
          label: 'Downloads',
          icon: InkIcons.downloadSimple,
        ),
        _HistoryAction(),
      ],
    );
  }
}

/// Independent from the catalogue feed: resume updates never rebuild its grid.
/// Continue reading shows in-progress positions from the existing account-scoped,
/// library-visibility-filtered snapshot; On Deck is reserved for series actions.
class _ResumeSection extends ConsumerWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref.watch(resumeEntriesProvider);
    return resume.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const InkEmptyState(
        icon: InkIcons.cloudSlash,
        title: 'Reading history unavailable',
      ),
      data: (entries) {
        final reading = [
          for (final entry in entries)
            if (!entry.onDeck) entry,
        ];
        if (reading.isEmpty) return const SizedBox.shrink();
        final window = MediaQuery.sizeOf(context);
        final columns = ref.watch(
          uiPreferencesProvider.select(
            (p) => (p.asData?.value ?? const UiPreferences()).homeColumnsFor(
              window.width,
              window.height,
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: InkPanel(
            framed: false,
            title: 'Continue reading',
            child: ResumeCarousel(entries: reading, columns: columns),
          ),
        );
      },
    );
  }
}

void _openHistory(BuildContext context) => context.go('/history');

/// Always-available icon action, independent of the resume shelf state.
class _HistoryAction extends StatelessWidget {
  const _HistoryAction();
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('reading-history-action'),
    tooltip: context.tr('Reading history'),
    onPressed: () => _openHistory(context),
    icon: const Icon(InkIcons.clockCounterClockwise),
  );
}

/// Primary destinations open above Home so Back restores its retained catalogue.
class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.destination,
    required this.label,
    required this.icon,
  });
  final String destination, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('open-$destination'),
    tooltip: context.tr(label),
    onPressed: () => context.go('/$destination'),
    icon: Icon(icon),
  );
}
