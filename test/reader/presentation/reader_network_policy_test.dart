import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/application/reader_network_policy.dart';

void main() {
  test(
    'fallback polls never overlap and cancellation drops late results',
    () async {
      final previous = ReaderNetworkPolicy.pollInterval;
      ReaderNetworkPolicy.pollInterval = const Duration(milliseconds: 10);
      addTearDown(() => ReaderNetworkPolicy.pollInterval = previous);
      final requests = <Completer<Map<String, bool>>>[];
      final firstRequest = Completer<void>(),
          secondRequest = Completer<void>(),
          firstValue = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReaderNetworkPolicy.channel, (call) async {
            if (call.method == 'events') return false;
            final response = Completer<Map<String, bool>>();
            requests.add(response);
            if (requests.length == 1) firstRequest.complete();
            if (requests.length == 2) secondRequest.complete();
            return response.future;
          });
      final seen = <ReaderNetworkSnapshot>[];
      final subscription = ReaderNetworkPolicy.watch().listen((value) {
        seen.add(value);
        if (!firstValue.isCompleted) firstValue.complete();
      });
      addTearDown(subscription.cancel);
      await firstRequest.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests.length, 1);
      requests.first.complete({'metered': false, 'dataSaver': false});
      await firstValue.future.timeout(const Duration(seconds: 3));
      expect(seen, [(constrained: false, paused: false)]);
      await secondRequest.future.timeout(const Duration(seconds: 3));
      await subscription.cancel();
      requests.last.complete({'metered': true, 'dataSaver': true});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests.length, 2);
      expect(seen.length, 1);
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReaderNetworkPolicy.channel, null),
  );
  test('Android policy propagates metered/data-saver flags without affecting foreground source', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ReaderNetworkPolicy.channel,
          (_) async => {'metered': true, 'dataSaver': true},
        );
    expect(await ReaderNetworkPolicy.current(), (
      constrained: true,
      paused: true,
    ));
  });
  test(
    'unavailable native cost metadata keeps conservative adjacent speculation',
    () async {
      expect(await ReaderNetworkPolicy.current(), (
        constrained: true,
        paused: false,
      ));
    },
  );

  test(
    'Android pushes policy changes without polling and drops duplicates',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var currentCalls = 0;
      messenger.setMockMethodCallHandler(ReaderNetworkPolicy.channel, (
        call,
      ) async {
        if (call.method == 'events') return true;
        currentCalls++;
        return {'metered': false, 'dataSaver': false};
      });
      messenger.setMockStreamHandler(
        ReaderNetworkPolicy.events,
        MockStreamHandler.inline(
          onListen: (_, events) {
            events.success({'metered': false, 'dataSaver': false});
            events.success({'metered': false, 'dataSaver': false});
            events.success({'metered': true, 'dataSaver': false});
          },
        ),
      );
      addTearDown(
        () => messenger.setMockStreamHandler(ReaderNetworkPolicy.events, null),
      );
      final seen = await ReaderNetworkPolicy.watch().take(2).toList();
      expect(seen, [
        (constrained: false, paused: false),
        (constrained: true, paused: false),
      ]);
      expect(currentCalls, 0);
    },
  );

  test('platforms without push events poll at the fallback interval', () async {
    final previous = ReaderNetworkPolicy.pollInterval;
    ReaderNetworkPolicy.pollInterval = const Duration(milliseconds: 10);
    addTearDown(() => ReaderNetworkPolicy.pollInterval = previous);
    var metered = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReaderNetworkPolicy.channel, (call) async {
          if (call.method == 'events') throw MissingPluginException();
          return {'metered': metered, 'dataSaver': false};
        });
    final seen = <ReaderNetworkSnapshot>[];
    final subscription = ReaderNetworkPolicy.watch().listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    metered = true;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await subscription.cancel();
    expect(seen, [
      (constrained: false, paused: false),
      (constrained: true, paused: false),
    ]);
  });
}
