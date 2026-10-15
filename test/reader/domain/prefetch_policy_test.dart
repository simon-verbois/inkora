import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/reader/domain/prefetch_policy.dart';
import 'package:inkora/reader/domain/reader_manifest.dart';
import 'package:inkora/reader/domain/webtoon_layout.dart';

import '../../support/reader_fakes.dart';

void main() {
  test(
    'paged prefetch prepares both next spread pages within metered limits',
    () {
      final policy = PrefetchPolicy(ReaderNetworkEstimate());
      final manifest = readerManifest();
      expect(
        policy
            .plan(manifest, 0, Duration.zero, visiblePages: 2)
            .map((d) => d.index),
        [2, 3],
      );
      policy.constrained = true;
      expect(
        policy
            .plan(manifest, 0, Duration.zero, visiblePages: 2)
            .map((d) => d.index),
        [2],
      );
    },
  );
  test(
    'latency, measured size and robust velocity change bounded lookahead',
    () {
      final network = ReaderNetworkEstimate();
      final policy = PrefetchPolicy(network, encodedBudget: 6 * 1024 * 1024);
      final manifest = readerManifest(
        count: 100,
        dimensions: List.generate(
          100,
          (_) => PageDimensions(1000, 1500, sizeBytes: 1024 * 1024),
        ),
      );
      policy.position(0, Duration.zero);
      final cold = policy.plan(manifest, 0, Duration.zero);
      for (var i = 0; i < 8; i++) {
        network.observe(
          const NetworkSample(
            Duration(milliseconds: 800),
            Duration(seconds: 2),
            1024 * 1024,
          ),
        );
      }
      policy.position(1, const Duration(milliseconds: 200));
      final fast = policy.plan(manifest, 1, const Duration(milliseconds: 200));
      expect(fast.length, greaterThan(cold.length));
      expect(
        fast.fold(0, (int sum, d) => sum + d.byteReservation),
        lessThanOrEqualTo(policy.encodedBudget),
      );
      expect(policy.bandwidthLimited, isTrue);
      expect(
        fast.map((d) => d.deadline),
        orderedEquals(fast.map((d) => d.deadline).toList()..sort()),
      );
      policy.constrained = true;
      expect(policy.plan(manifest, 1, Duration.zero).length, 1);
      policy.paused = true;
      expect(policy.plan(manifest, 1, Duration.zero), isEmpty);
    },
  );
  test('throughput gain cautiously grows slots; saturation reduces them within 1..8', () {
    final network = ReaderNetworkEstimate();
    for (var i = 0; i < 4; i++) {
      network.observe(
        const NetworkSample(
          Duration(milliseconds: 250),
          Duration(seconds: 1),
          1024 * 1024,
        ),
      );
    }
    for (var i = 0; i < 40; i++) {
      network.observe(
        NetworkSample(
          const Duration(milliseconds: 20),
          const Duration(milliseconds: 100),
          (i + 2) * 1024 * 1024,
        ),
      );
    }
    expect(network.concurrency, greaterThan(2));
    expect(network.concurrency, lessThanOrEqualTo(8));
    for (var i = 0; i < 8; i++) {
      network.failed();
    }
    expect(network.concurrency, 1);
    network.recoverForeground();
    expect(network.concurrency, 2);
    expect(network.failures, 0);
  });
  test(
    'webtoon demand uses viewport distance even without a page crossing',
    () {
      final network = ReaderNetworkEstimate();
      final policy = PrefetchPolicy(network);
      final manifest = readerManifest(
        dimensions: [
          PageDimensions(100, 1200),
          PageDimensions(100, 100),
          PageDimensions(100, 100),
          PageDimensions(100, 100),
        ],
      );
      final layout = WebtoonLayout(manifest.pages, 100, 0);
      policy.position(0, Duration.zero, pixels: true);
      policy.position(900, const Duration(seconds: 1), pixels: true);
      final plan = policy.plan(
        manifest,
        0,
        const Duration(seconds: 1),
        layout: layout,
        offset: 900,
        viewportHeight: 100,
      );
      expect(plan.first.index, 1);
      expect(plan.first.deadline, lessThan(const Duration(seconds: 2)));
      expect(
        policy.position(500, const Duration(seconds: 2), pixels: true),
        isTrue,
      );
      expect(policy.direction, -1);
    },
  );
  test('unknown and huge pages cannot exceed byte reservations', () {
    final policy = PrefetchPolicy(
      ReaderNetworkEstimate(),
      encodedBudget: 1024 * 1024,
    );
    expect(
      policy.plan(
        readerManifest(
          dimensions: List.generate(4, (_) => PageDimensions(10, 10)),
        ),
        0,
        Duration.zero,
      ),
      isEmpty,
    );
    final network = policy.network;
    network.observe(const NetworkSample(Duration.zero, Duration.zero, 100));
    expect(network.throughput, 1250000);
  });

  test('stationary tall webtoon prepares six next strips within cost and byte limits', () {
    final manifest = readerManifest(
      dimensions: List.generate(
        10,
        (_) => PageDimensions(720, 5000, sizeBytes: 1024 * 1024),
      ),
    );
    final layout = WebtoonLayout(manifest.pages, 400, 0);
    final policy = PrefetchPolicy(ReaderNetworkEstimate());
    List<PrefetchDemand> plan() => policy.plan(
      manifest,
      0,
      Duration.zero,
      layout: layout,
      viewportHeight: 900,
    );
    expect(plan().map((p) => p.index), [1, 2, 3, 4, 5, 6]);
    policy.constrained = true;
    expect(plan().map((p) => p.index), [1]);
    policy.paused = true;
    expect(plan(), isEmpty);
    final bounded = PrefetchPolicy(
      ReaderNetworkEstimate(),
      encodedBudget: 1400000,
    );
    expect(
      bounded
          .plan(manifest, 0, Duration.zero, layout: layout, viewportHeight: 900)
          .length,
      1,
    );
  });

  test('spreads keep three upcoming groups encoded even at a slow pace', () {
    final policy = PrefetchPolicy(ReaderNetworkEstimate());
    final manifest = readerManifest(count: 20);
    expect(
      policy
          .plan(manifest, 4, Duration.zero, visiblePages: 2)
          .map((d) => d.index),
      [6, 7, 8, 9, 10, 11],
    );
    expect(
      policy.plan(manifest, 4, Duration.zero).map((d) => d.index).take(2),
      [5, 6],
    );
  });
}
