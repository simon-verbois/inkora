import '../offline/application/offline_coordinator.dart';
import '../offline/data/progress_sync.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/application/cover_providers.dart';
import '../reader/application/reader_providers.dart';
import '../reader/presentation/reader_content_bounds.dart';

/// On OS memory pressure Flutter already clears its decoded ImageCache; this
/// also drops Inkora's own encoded LRUs (reader pages, covers). Both refill
/// from their disk tiers, so trimming never loses user data.
final memoryPressureProvider = Provider<void>((ref) {
  final observer = _MemoryPressureObserver(() {
    ReaderContentBounds.cache.clear();
    ref.read(coverRepositoryProvider).asData?.value?.trimMemory();
    if (ref.exists(offlineCoordinatorProvider)) {
      final remote = ref
          .read(offlineCoordinatorProvider)
          .asData
          ?.value
          ?.sync
          .remote;
      if (remote is KomgaProgressRemote) remote.trimMemory();
    }
    // Never instantiate an inactive reader repository just to trim it.
    if (ref.exists(readerRepositoryProvider)) {
      ref.read(readerRepositoryProvider).asData?.value?.memory.clear();
    }
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

final class _MemoryPressureObserver with WidgetsBindingObserver {
  _MemoryPressureObserver(this.onPressure);
  final VoidCallback onPressure;
  @override
  void didHaveMemoryPressure() => onPressure();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      ReaderContentBounds.cache.pause(state != AppLifecycleState.resumed);
}
