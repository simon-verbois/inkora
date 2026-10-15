import 'package:dio/dio.dart';

import '../../errors/failure_kind.dart';

/// Contains no response body, request, URL or credential-bearing exception.
final class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.retryAfter});

  final FailureKind kind;
  final String message;
  final Duration? retryAfter;

  bool get allowsOfflineRestore =>
      kind == FailureKind.transientNetwork ||
      kind == FailureKind.offlineUnavailable ||
      kind == FailureKind.rateLimited;

  static ApiFailure fromDio(DioException error) {
    final status = error.response?.statusCode;
    final retry = error.response?.headers.value('retry-after');
    Duration? delay;
    final seconds = int.tryParse(retry ?? '');
    if (seconds != null && seconds >= 0) delay = Duration(seconds: seconds);
    if (error.type == DioExceptionType.cancel) {
      return const ApiFailure(FailureKind.cancelled, 'Request cancelled.');
    }
    if (error.error is FormatException || error.error is TypeError) {
      return const ApiFailure(
        FailureKind.corruptContent,
        'Invalid server response.',
      );
    }
    return switch (status) {
      401 => const ApiFailure(
        FailureKind.authentication,
        'Authentication failed. Please sign in again.',
      ),
      403 => const ApiFailure(FailureKind.permission, 'Access denied.'),
      404 => const ApiFailure(FailureKind.notFound, 'Resource unavailable.'),
      429 => ApiFailure(
        FailureKind.rateLimited,
        'Too many requests. Try again later.',
        retryAfter: delay,
      ),
      int s when s >= 500 => ApiFailure(
        FailureKind.transientNetwork,
        'The server is temporarily unavailable.',
        retryAfter: delay,
      ),
      int _ => const ApiFailure(
        FailureKind.serverRejected,
        'The server rejected the request.',
      ),
      _ when error.type == DioExceptionType.badCertificate => const ApiFailure(
        FailureKind.serverRejected,
        'The server TLS certificate could not be verified.',
      ),
      _ => const ApiFailure(
        FailureKind.offlineUnavailable,
        'Unable to reach the server. Check your connection.',
      ),
    };
  }

  @override
  String toString() => message;
}
