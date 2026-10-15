import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connection/application/session_controller.dart';

/// Retain a few inactive SQL subscriptions, keeping their current data available.
/// This owns provider lifetimes, not a second copy of catalogue metadata.
final class NavigationRetention {
  NavigationRetention({
    this.capacity = 12,
    this.duration = const Duration(minutes: 2),
  });
  final int capacity;
  final Duration duration;
  final _inactive = <Object, ({Timer timer, void Function() release})>{};
  bool _closed = false;

  void retain(Object key, void Function() release) {
    if (_closed) {
      release();
      return;
    }
    resume(key);
    _inactive[key] = (
      timer: Timer(duration, () {
        _inactive.remove(key);
        release();
      }),
      release: release,
    );
    while (_inactive.length > capacity) {
      final entry = _inactive.remove(_inactive.keys.first)!;
      entry.timer.cancel();
      entry.release();
    }
  }

  void resume(Object key) => _inactive.remove(key)?.timer.cancel();

  void close() {
    _closed = true;
    final entries = _inactive.values.toList();
    _inactive.clear();
    for (final entry in entries) {
      entry.timer.cancel();
      entry.release();
    }
  }
}

final navigationRetentionProvider = Provider<NavigationRetention>((ref) {
  ref.watch(sessionProvider.select((state) => state.session?.accountId));
  final retention = NavigationRetention();
  ref.onDispose(retention.close);
  return retention;
});

Stream<T> retainNavigationStream<T>(Ref ref, Stream<T> stream) {
  if (!ref.mounted) return const Stream.empty();
  final retention = ref.watch(navigationRetentionProvider);
  final key = Object();
  ref.onDispose(() => retention.resume(key));
  return Stream.multi((controller) {
    var retained = false;
    final subscription = stream.listen(
      (value) {
        if (!ref.mounted) return;
        if (!retained) {
          retained = true;
          final link = ref.keepAlive();
          ref.onCancel(() => retention.retain(key, link.close));
          ref.onResume(() => retention.resume(key));
          if (ref.isPaused) retention.retain(key, link.close);
        }
        controller.add(value);
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    controller
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = subscription.cancel;
  });
}
