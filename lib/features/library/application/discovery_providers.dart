import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discovery_repository.dart';
import '../domain/discovery.dart';
import '../domain/resume_entry.dart';
import 'catalogue_providers.dart';
import 'navigation_retention.dart';

final discoveryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

// Capture once at app startup, independently of account and navigation changes.
final discoveryLaunchDateProvider = Provider<DateTime>(
  (ref) => ref.watch(discoveryClockProvider)(),
);

final discoveryRepositoryProvider = FutureProvider<DiscoveryRepository?>((
  ref,
) async {
  final launchedAt = ref.watch(discoveryLaunchDateProvider);
  final catalogue = await ref.watch(catalogueRepositoryProvider.future);
  if (!ref.mounted || catalogue == null) return null;
  return DiscoveryRepository(catalogue.store, clock: () => launchedAt);
});

final discoverySectionsProvider = StreamProvider.autoDispose<List<DiscoveryPage>>((
  ref,
) async* {
  // Discovery only uses resume series/genres. Page-turn progress updates
  // must not re-run the selection transaction and rebuild every row.
  ref.watch(
    resumeEntriesProvider.select(
      (state) => (
        state.hasValue,
        state.hasError,
        state.hasValue
            ? [
                for (final entry in state.requireValue)
                  '${entry.readingIdentity}:${entry.item.metadata.genres.join(',')}',
              ].join('|')
            : null,
      ),
    ),
  );
  final resumeState = ref.read(resumeEntriesProvider);
  final resume = resumeState.hasValue
      ? resumeState.requireValue
      : resumeState.hasError
      ? <ResumeEntry>[]
      : await ref.read(resumeEntriesProvider.future);
  if (!ref.mounted) return;
  final repository = await ref.watch(discoveryRepositoryProvider.future);
  if (!ref.mounted) return;
  if (repository == null) {
    yield List.generate(
      DiscoveryPage.sectionCount,
      (_) => const DiscoveryPage(DiscoveryTheme.surprise, []),
    );
    return;
  }
  yield* retainNavigationStream(ref, repository.watchSections(resume));
});
