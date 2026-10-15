import 'content_key.dart';

/// Bounded samples for a reader run. Benchmark reports distinguish intent,
/// acquisition and first rendered frame; warm encoded is not decoded-ready.
final class ReaderTelemetry {
  final readinessMicros = <int>[];
  final decodeMicros = <int>[];
  int presentations = 0;
  int buffered = 0;
  void presented(
    ContentKey key,
    Duration elapsed, {
    required bool hadPlaceholder,
  }) {
    presentations++;
    if (hadPlaceholder) buffered++;
    readinessMicros.add(elapsed.inMicroseconds);
    if (readinessMicros.length > 10000) readinessMicros.removeAt(0);
  }

  void decoded(Duration elapsed) {
    decodeMicros.add(elapsed.inMicroseconds);
    if (decodeMicros.length > 10000) decodeMicros.removeAt(0);
  }

  Map<String, Object> toJson() {
    final sorted = readinessMicros.toList()..sort();
    int percentile(double p) =>
        sorted.isEmpty ? 0 : sorted[(sorted.length * p).ceil() - 1];
    return {
      'presentations': presentations,
      'bufferedTransitions': buffered,
      'p50ReadinessMicros': percentile(.5),
      'p95ReadinessMicros': percentile(.95),
      'p99ReadinessMicros': percentile(.99),
      'readinessMicros': List.of(readinessMicros),
      'decodeMicros': List.of(decodeMicros),
    };
  }
}
