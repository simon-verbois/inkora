import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Test-only streaming link model: RTT, shared bandwidth, jitter and retransmit
/// stalls. No sockets or production TLS policy changes. Not an OS packet proxy.
final class ShapedPageAdapter implements HttpClientAdapter {
  ShapedPageAdapter(
    this.image, {
    required this.rttMs,
    required this.mbps,
    this.jitterMs = 0,
    this.stallEvery = 0,
  });
  final Uint8List image;
  final int rttMs;
  final double mbps;
  final int jitterMs;
  final int stallEvery;
  bool offline = false;
  int requests = 0;
  int deliveredBytes = 0;
  int cancelled = 0;
  int peakTransfers = 0;
  int _ticks = 0;
  Timer? _timer;
  final _active = <_Transfer>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Synthetic offline link',
      );
    }
    requests++;
    final jitter = ((requests % 3) - 1) * jitterMs;
    final readyAt = DateTime.now().add(
      Duration(milliseconds: math.max(0, rttMs + jitter)),
    );
    final transfer = _Transfer(readyAt);
    final controller = StreamController<Uint8List>(
      onCancel: () {
        if (_active.remove(transfer)) cancelled++;
      },
    );
    transfer.controller = controller;
    _active.add(transfer);
    peakTransfers = math.max(peakTransfers, _active.length);
    cancelFuture?.then((_) {
      if (_active.remove(transfer)) {
        cancelled++;
        controller.close();
      }
    });
    _timer ??= Timer.periodic(const Duration(milliseconds: 20), (_) => _tick());
    return ResponseBody(
      controller.stream,
      200,
      headers: {
        'content-type': ['image/png'],
        'content-length': ['${image.length}'],
      },
    );
  }

  void _tick() {
    _ticks++;
    final now = DateTime.now();
    if (stallEvery > 0 && _ticks % stallEvery == 0) {
      for (final transfer in _active) {
        transfer.readyAt = now.add(Duration(milliseconds: rttMs));
      }
    }
    final ready = _active.where((t) => !now.isBefore(t.readyAt)).toList();
    if (ready.isEmpty) return;
    final chunk = math.max(
      1,
      (mbps * 1000000 / 8 * .02 / ready.length).floor(),
    );
    for (final transfer in ready) {
      final end = math.min(image.length, transfer.offset + chunk);
      transfer.controller.add(
        Uint8List.sublistView(image, transfer.offset, end),
      );
      deliveredBytes += end - transfer.offset;
      transfer.offset = end;
      if (end == image.length) {
        _active.remove(transfer);
        transfer.controller.close();
      }
    }
  }

  @override
  void close({bool force = false}) {
    _timer?.cancel();
    _timer = null;
    for (final transfer in _active.toList()) {
      transfer.controller.close();
    }
    _active.clear();
  }
}

final class _Transfer {
  _Transfer(this.readyAt);
  DateTime readyAt;
  int offset = 0;
  late StreamController<Uint8List> controller;
}
