import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/application/navigation_retention.dart';

void main() {
  testWidgets(
    'inactive navigation retention evicts, expires and cancels timers on resume',
    (tester) async {
      final retention = NavigationRetention(
        capacity: 2,
        duration: const Duration(seconds: 10),
      );
      addTearDown(retention.close);
      final released = <String>[];
      retention.retain('first', () => released.add('first'));
      retention.retain('second', () => released.add('second'));
      retention.retain('third', () => released.add('third'));
      expect(released, ['first']);
      retention.resume('second');
      await tester.pump(const Duration(seconds: 10));
      expect(released, ['first', 'third']);
      retention.retain('last', () => released.add('last'));
      retention.close();
      retention.retain(
        'disposed-account',
        () => released.add('disposed-account'),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(released, ['first', 'third', 'last', 'disposed-account']);
    },
  );

  test('returning to a retained query immediately shows cached data and resumes updates without resubscribing', () async {
    final changes = StreamController<int>.broadcast(sync: true);
    var subscriptions = 0;
    var cancellations = 0;
    final cancelled = Completer<void>();
    final query = StreamProvider.autoDispose<int>(
      (ref) => retainNavigationStream(
        ref,
        Stream.multi((controller) {
          subscriptions++;
          controller.add(1);
          final subscription = changes.stream.listen(controller.add);
          controller.onCancel = () {
            cancellations++;
            cancelled.complete();
            return subscription.cancel();
          };
        }),
      ),
    );
    final retention = NavigationRetention(
      duration: const Duration(milliseconds: 100),
    );
    final container = ProviderContainer(
      overrides: [navigationRetentionProvider.overrideWithValue(retention)],
    );
    addTearDown(() async {
      container.dispose();
      retention.close();
      await changes.close();
    });
    final first = container.listen(query, (_, _) {});
    expect(await container.read(query.future), 1);
    first.close();
    await container.pump();
    changes.add(2);
    await container.pump();
    final updated = Completer<void>();
    final returned = container.listen(query, (_, next) {
      if (next.asData?.value == 2) updated.complete();
    });
    expect(container.read(query).requireValue, 1);
    await updated.future;
    await container.pump();
    expect(container.read(query).requireValue, 2);
    expect(subscriptions, 1);
    expect(cancellations, 0);
    returned.close();
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await container.pump();
    await cancelled.future;
    expect(container.exists(query), isFalse);
    expect(cancellations, 1);
  });
}
