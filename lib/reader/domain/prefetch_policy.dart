import 'dart:math' as math;

import 'reader_manifest.dart';
import 'webtoon_layout.dart';

/// Completed network work only: queue/disk/cancelled bytes never inflate the link.
final class NetworkSample {
  const NetworkSample(this.firstByte, this.transfer, this.bytes);
  final Duration firstByte;
  final Duration transfer;
  final int bytes;
  double get seconds => (firstByte + transfer).inMicroseconds / 1e6;
  double get bytesPerSecond =>
      bytes / math.max(.001, transfer.inMicroseconds / 1e6);
}

final class ReaderNetworkEstimate {
  final _samples = <NetworkSample>[];
  double latencySeconds = .25;
  double throughput = 1250000;
  double meanPageBytes = 768 * 1024;
  double decodeSeconds = .05;
  int concurrency = 2;
  int failures = 0;
  double foregroundQueueSeconds = 0;
  double? _previousThroughput;
  int _healthy = 0;
  double get serviceP95 {
    if (_samples.isEmpty) return latencySeconds + meanPageBytes / throughput;
    final times = _samples.map((s) => s.seconds).toList()..sort();
    return times[(times.length * .95).ceil() - 1];
  }

  double get horizon =>
      (serviceP95 + decodeSeconds + latencySeconds * .5 + .15).clamp(.3, 15);
  void observe(NetworkSample sample) {
    if (sample.bytes <= 0 ||
        sample.transfer <= Duration.zero ||
        sample.firstByte < Duration.zero) {
      return;
    }
    _samples.add(sample);
    if (_samples.length > 32) _samples.removeAt(0);
    latencySeconds =
        .75 * latencySeconds + .25 * sample.firstByte.inMicroseconds / 1e6;
    throughput = .75 * throughput + .25 * sample.bytesPerSecond;
    meanPageBytes = .75 * meanPageBytes + .25 * sample.bytes;
    failures = 0;
    if (++_healthy >= 4) {
      // Add a slot only with measured improvement, never on a connectivity label.
      if (_previousThroughput != null &&
          throughput > _previousThroughput! * 1.1 &&
          foregroundQueueSeconds <= .1) {
        concurrency = math.min(8, concurrency + 1);
      }
      _previousThroughput = throughput;
      _healthy = 0;
    }
  }

  void observeDecode(Duration duration) {
    decodeSeconds = .8 * decodeSeconds + .2 * duration.inMicroseconds / 1e6;
  }

  void failed() {
    failures++;
    _healthy = 0;
    concurrency = math.max(1, concurrency ~/ 2);
  }

  void recoverForeground() {
    // A successful visible request allows speculation to probe again.
    failures = 0;
    if (concurrency == 1) concurrency = 2;
  }
}

final class PrefetchDemand {
  const PrefetchDemand(this.index, this.deadline, this.byteReservation);
  final int index;
  final Duration deadline;
  final int byteReservation;
}

/// Monotonic input; injected timestamps make controller behavior deterministic.
final class PrefetchPolicy {
  PrefetchPolicy(this.network, {this.encodedBudget = 32 * 1024 * 1024});
  final ReaderNetworkEstimate network;
  final int encodedBudget;
  double pagesPerSecond = .5;
  double pixelsPerSecond = 0;
  int direction = 1;
  Duration? _lastTime;
  double? _lastPosition;
  bool constrained = false;
  bool paused = false;
  bool get bandwidthLimited =>
      pagesPerSecond * network.meanPageBytes > network.throughput;

  bool position(double position, Duration now, {bool pixels = false}) {
    final old = _lastPosition;
    final time = _lastTime;
    final delta = old == null ? 0.0 : position - old;
    final reversed = delta != 0 && delta.sign.toInt() != direction;
    if (delta != 0) direction = delta.sign.toInt();
    if (time != null &&
        now - time >= const Duration(milliseconds: 100) &&
        delta != 0) {
      final velocity = delta.abs() / ((now - time).inMicroseconds / 1e6);
      if (pixels) {
        pixelsPerSecond = .5 * pixelsPerSecond + .5 * velocity;
      } else {
        pagesPerSecond = (.5 * pagesPerSecond + .5 * velocity).clamp(.05, 20);
      }
    }
    // Keep the sampling anchor across high-frequency scroll events.
    if (time == null || now - time >= const Duration(milliseconds: 100)) {
      _lastTime = now;
      _lastPosition = position;
    }
    return reversed;
  }

  void resetMotion() {
    _lastTime = null;
    _lastPosition = null;
    pixelsPerSecond = 0;
  }

  List<PrefetchDemand> plan(
    ReaderManifest manifest,
    int current,
    Duration now, {
    WebtoonLayout? layout,
    double offset = 0,
    double viewportHeight = 0,
    int visiblePages = 1,
  }) {
    if (paused || network.failures > 0) return const [];
    final budget = constrained ? encodedBudget ~/ 4 : encodedBudget;
    var reserved = 0;
    final result = <PrefetchDemand>[];
    final velocity = math.max(.05, pagesPerSecond);
    final horizon = network.horizon + 1 / velocity; // one measured-time reserve
    final maxPages = constrained ? 1 : 64;
    for (var distance = 1; distance <= maxPages; distance++) {
      final index = direction > 0
          ? current + visiblePages - 1 + distance
          : current - distance;
      if (index < 0 || index >= manifest.pages.length) break;
      double due;
      if (layout != null) {
        final pixels = direction > 0
            ? layout.offsets[index] - offset - viewportHeight
            : offset - layout.offsets[index + 1];
        final speed = math.max(viewportHeight * .5, pixelsPerSecond);
        due = math.max(0, pixels) / math.max(1, speed);
      } else {
        due = distance / velocity;
      }
      // Tall webtoon strips can span several screens. Keep the next six strips
      // encoded even at rest; measured deadlines still extend the window.
      // Spreads keep three upcoming groups encoded so consecutive swipes never
      // outrun acquisition at a slow measured reading pace.
      final minimumAhead = constrained
          ? 1
          : layout != null
          ? 6
          : visiblePages > 1
          ? visiblePages * 3
          : 2;
      if (distance > minimumAhead && due > horizon) break;
      final size = manifest.pages[index].sizeBytes;
      // Unknown sizes reserve the full stream cap. Known sizes include slack,
      // enforced by the transport rather than merely assumed by the controller.
      final bytes = size == 0
          ? 32 * 1024 * 1024
          : math.min(32 * 1024 * 1024, size + size ~/ 4 + 65536);
      if (reserved + bytes > budget) break;
      reserved += bytes;
      result.add(
        PrefetchDemand(
          index,
          now + Duration(microseconds: (due * 1e6).round()),
          bytes,
        ),
      );
    }
    return result;
  }
}
