import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef ReaderNetworkSnapshot = ({bool constrained, bool paused});

/// Platform cost restrictions limit speculation only, never visible demand.
abstract final class ReaderNetworkPolicy {
  static const channel = MethodChannel('inkora/reader_network_policy');
  static const events = EventChannel('inkora/reader_network_policy/events');

  /// Fallback cadence where the platform cannot push changes (iOS until its
  /// native stream is validated, or an engine without the event channel).
  static Duration pollInterval = const Duration(seconds: 5);

  static Future<ReaderNetworkSnapshot> current() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final policy = await channel.invokeMapMethod<String, bool>('current');
        return _snapshot(policy);
      } on MissingPluginException {
        // Unknown cost: conservative adjacent-page-only lookahead.
      } on PlatformException {
        // Reading still works if policy metadata is unavailable.
      }
    }
    return (constrained: true, paused: false);
  }

  static ReaderNetworkSnapshot _snapshot(Map<Object?, Object?>? policy) => (
    constrained: policy?['metered'] as bool? ?? true,
    paused: policy?['dataSaver'] as bool? ?? true,
  );

  static Future<bool> _supportsEvents() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await channel.invokeMethod<bool>('events') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Current policy followed by every change. Android pushes changes from a
  /// network callback (no polling); other platforms poll [current] at
  /// [pollInterval]. Consecutive identical snapshots are not repeated.
  static Stream<ReaderNetworkSnapshot> watch() => Stream.multi((controller) {
    StreamSubscription<Object?>? subscription;
    Timer? timer;
    var cancelled = false;
    ReaderNetworkSnapshot? last;
    void emit(ReaderNetworkSnapshot snapshot) {
      if (cancelled || snapshot == last) return;
      last = snapshot;
      controller.add(snapshot);
    }

    void poll() {
      Future<void> tick() async => emit(await current());
      unawaited(tick());
      timer = Timer.periodic(pollInterval, (_) => unawaited(tick()));
    }

    unawaited(
      _supportsEvents().then((push) {
        if (cancelled) return;
        if (!push) return poll();
        subscription = events.receiveBroadcastStream().listen(
          (event) => emit(_snapshot(event as Map<Object?, Object?>?)),
          onError: (Object _) {
            unawaited(subscription?.cancel());
            subscription = null;
            if (!cancelled) poll();
          },
        );
      }),
    );
    controller.onCancel = () {
      cancelled = true;
      timer?.cancel();
      return subscription?.cancel();
    };
  });
}
