import 'dart:async';
import 'dart:typed_data';

import 'content_key.dart';
import 'prefetch_policy.dart';

abstract interface class CancellationSignal {
  bool get isCancelled;
  Future<void> get whenCancelled;
}

/// Idempotent cancellation that adapters may map to native/HTTP cancellation.
final class CancellationController implements CancellationSignal {
  final _cancelled = Completer<void>();

  @override
  bool get isCancelled => _cancelled.isCompleted;

  @override
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

final class EncodedPage {
  EncodedPage({
    required this.key,
    required this.bytes,
    required this.mediaType,
    this.networkSample,
  });

  final ContentKey key;
  final Uint8List bytes;
  final String mediaType;
  final NetworkSample? networkSample;
}

/// Implementations must honor cancellation and return the requested revision.
/// The concrete resolver orders verified downloads, valid disk cache, then network.
abstract interface class PageSource {
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  });
}

/// A decoder failure may require dropping encoded bytes before a retry.
abstract interface class InvalidatablePageSource implements PageSource {
  Future<void> invalidate(ContentKey key);
}
