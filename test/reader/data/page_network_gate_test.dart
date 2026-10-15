import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/data/page_network_gate.dart';
import 'package:inkora/reader/domain/page_source.dart';

void main() {
  test(
    'preemptible artwork borrows idle capacity while reader demand cancels it',
    () async {
      final gate = PageNetworkGate();
      var cancelled = 0;
      final covers = <PageRequest>[];
      for (var i = 0; i < 2; i++) {
        late PageRequest request;
        request = PageRequest(
          priority: PagePriority.download,
          maximumBytes: 2 * 1024 * 1024,
          borrowForegroundSlot: true,
          onForegroundDemand: () {
            cancelled++;
            gate.release(request);
          },
        );
        covers.add(request);
        await gate.acquire(CancellationController(), request);
      }
      expect(gate.active, 2);
      expect(gate.speculativeBytes, 4 * 1024 * 1024);
      final reader = PageRequest();
      await gate.acquire(CancellationController(), reader);
      expect(cancelled, 2);
      expect(gate.active, 1);
      gate.release(reader);
      expect(gate.active, 0);
    },
  );
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  for (final borrowedFirst in [true, false]) {
    test('ordinary capacity survives borrowed-first=$borrowedFirst admission', () async {
      final gate = PageNetworkGate();
      var preemptions = 0;
      late PageRequest borrowed;
      borrowed = PageRequest(
        priority: PagePriority.download,
        maximumBytes: 16 * 1024 * 1024,
        borrowForegroundSlot: true,
        onForegroundDemand: () {
          preemptions++;
          gate.release(borrowed);
        },
      );
      final ordinary = PageRequest(
        priority: PagePriority.download,
        maximumBytes: 16 * 1024 * 1024,
      );
      final first = borrowedFirst ? borrowed : ordinary;
      final second = borrowedFirst ? ordinary : borrowed;
      await gate.acquire(CancellationController(), first);
      var admitted = false;
      final ready = gate
          .acquire(CancellationController(), second)
          .then((_) => admitted = true);
      await flush();
      // Fail immediately on starvation, releasing the first lease for cleanup.
      if (!admitted) {
        gate.release(first);
        await ready;
        gate.release(second);
        fail('A borrowed lease consumed ordinary capacity with a free slot.');
      }
      await ready;
      expect(gate.active, 2);
      expect(gate.speculativeBytes, 32 * 1024 * 1024);
      final foreground = PageRequest();
      await gate.acquire(CancellationController(), foreground);
      expect(preemptions, 1);
      expect(gate.active, 2);
      expect(gate.speculativeBytes, 16 * 1024 * 1024);
      gate.release(foreground);
      gate.release(ordinary);
      expect(gate.active, 0);
      expect(gate.waiting, 0);
      expect(gate.speculativeBytes, 0);
    });
  }
  test(
    'borrowed leases retain the byte cap and promotion releases reservations',
    () async {
      final gate = PageNetworkGate();
      final borrowed = PageRequest(
        priority: PagePriority.download,
        borrowForegroundSlot: true,
        onForegroundDemand: () {},
      );
      await gate.acquire(CancellationController(), borrowed);
      final ordinary = PageRequest(
        priority: PagePriority.lookahead,
        maximumBytes: 1,
      );
      var admitted = false;
      final ready = gate
          .acquire(CancellationController(), ordinary)
          .then((_) => admitted = true);
      await flush();
      expect(admitted, false);
      expect(gate.speculativeBytes, 32 * 1024 * 1024);
      gate.promote(borrowed);
      await ready;
      expect(gate.speculativeBytes, 1);
      gate.release(borrowed);
      gate.release(ordinary);
      expect(gate.active, 0);
      expect(gate.speculativeBytes, 0);
    },
  );
  test(
    'reserved capacity admits visible demand ahead of speculative deadlines',
    () async {
      final gate = PageNetworkGate();
      final speculative = PageRequest(priority: PagePriority.lookahead);
      await gate.acquire(CancellationController(), speculative);
      final queued = PageRequest(priority: PagePriority.lookahead);
      var started = false;
      final waiting = gate
          .acquire(CancellationController(), queued)
          .then((_) => started = true);
      await flush();
      expect(started, false);
      final visible = PageRequest();
      await gate.acquire(CancellationController(), visible);
      expect(gate.active, 2);
      expect(started, false);
      gate.release(visible);
      expect(started, false);
      gate.release(speculative);
      await waiting;
      gate.release(queued);
      expect(gate.active, 0);
    },
  );
  test('promotion of an existing queued flight gets reserved slot without another request', () async {
    final gate = PageNetworkGate();
    final active = PageRequest(priority: PagePriority.lookahead);
    await gate.acquire(CancellationController(), active);
    final promoted = PageRequest(priority: PagePriority.chapter);
    final ready = gate.acquire(CancellationController(), promoted);
    expect(gate.waiting, 1);
    gate.promote(promoted);
    await ready;
    expect(gate.active, 2);
    expect(gate.waiting, 0);
    gate.release(active);
    gate.release(promoted);
  });
  test('byte budget and deadline priority hold at high concurrency', () async {
    final gate = PageNetworkGate(limit: 8);
    final full = PageRequest(priority: PagePriority.lookahead);
    await gate.acquire(CancellationController(), full);
    final order = <int>[];
    final late = PageRequest(
      priority: PagePriority.lookahead,
      deadline: const Duration(seconds: 4),
      maximumBytes: 10,
    );
    final soon = PageRequest(
      priority: PagePriority.lookahead,
      deadline: const Duration(seconds: 1),
      maximumBytes: 10,
    );
    final a = gate.acquire(CancellationController(), late).then((_) {
      order.add(4);
      gate.release(late);
    });
    final b = gate.acquire(CancellationController(), soon).then((_) {
      order.add(1);
      gate.release(soon);
    });
    expect(gate.speculativeBytes, 32 * 1024 * 1024);
    gate.release(full);
    await Future.wait([a, b]);
    expect(order, [1, 4]);
  });
  test('cancelled obsolete queue disappears in same microtask; reduced limit drains safely', () async {
    final gate = PageNetworkGate();
    final active = PageRequest(priority: PagePriority.lookahead);
    await gate.acquire(CancellationController(), active);
    final signal = CancellationController();
    final result = gate.acquire(
      signal,
      PageRequest(priority: PagePriority.lookahead),
    );
    final checked = expectLater(result, throwsA(isA<Exception>()));
    signal.cancel();
    await checked;
    expect(gate.waiting, 0);
    gate.estimate.failed();
    gate.release(active);
    expect(gate.active, 0);
  });
}
