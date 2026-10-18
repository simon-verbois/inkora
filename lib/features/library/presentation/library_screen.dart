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
  Widget build(BuildContext context) => const CatalogueScreen(
    kind: CatalogueKind.series,
    embedded: true,
    header: _ResumeSection(),
  );
}

/// Independent from the catalogue feed: resume updates never rebuild its grid.
class _ResumeSection extends ConsumerWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref.watch(resumeEntriesProvider);
    return resume.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(16),
        child: LText('Reading history unavailable'),
      ),
      data: (entries) => entries.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: InkPanel(
                framed: false,
                title: context.tr('Continue reading'),
                child: ResumeCarousel(
                  entries: entries,
                  density:
                      ref.watch(
                        uiPreferencesProvider.select(
                          (p) => p.asData?.value.density,
                        ),
                      ) ??
                      CatalogueDensity.comfortable,
                ),
              ),
            ),
    );
  }
}
