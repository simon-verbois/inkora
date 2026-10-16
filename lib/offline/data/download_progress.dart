import 'dart:async';

/// Ephemeral transfer telemetry. Durable availability still comes from verified
/// job/part rows. No SQLite writes or timers run for byte notifications.
final class DownloadProgress {
  final _clock = Stopwatch()..start();
  final _updates = StreamController<(String, double)>.broadcast(sync: true);
  String? _job;
  int _total = 1, _lastEmission = -200;
  final _pages = <int, double>{};
  double _value = 0;
  bool _closed = false;

  void begin(String job, int total, Iterable<int> completed) {
    _job = job;
    _total = total;
    _pages.clear();
    for (final page in completed) {
      _pages[page] = 1;
    }
    _lastEmission = -200;
    _publish(force: true);
  }

  void received(String job, int page, int received, int total) {
    if (_closed || job != _job || total <= 0) return;
    // Leave a small verification tail; transferred bytes are not ready files.
    _pages[page] = (received / total).clamp(0, 1) * .98;
    _publish();
  }

  void verified(String job, int page) {
    if (_closed || job != _job) return;
    _pages[page] = 1;
    _publish(force: true);
  }

  void _publish({bool force = false}) {
    if (_closed || _job == null || _total <= 0) return;
    final now = _clock.elapsedMilliseconds;
    if (!force && now - _lastEmission < 200) return;
    final value = (_pages.values.fold(0.0, (a, b) => a + b) / _total).clamp(
      0.0,
      1.0,
    );
    if (!force && value == _value) return;
    _value = value;
    _lastEmission = now;
    _updates.add((_job!, value));
  }

  Stream<double?> watch(String job) => Stream.multi((controller) {
    controller.add(job == _job ? _value : null);
    final subscription = _updates.stream
        .where((event) => event.$1 == job)
        .listen((event) => controller.add(event.$2), onDone: controller.close);
    controller.onCancel = subscription.cancel;
  });

  void close() {
    _closed = true;
    _pages.clear();
    unawaited(_updates.close());
  }
}
