import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'server_endpoint.dart';

/// Validated TLS, bounded timeouts and no authenticated redirect replay.
Dio createHttpClient(ServerEndpoint endpoint) {
  return Dio(
      BaseOptions(
        baseUrl: endpoint.uri.toString(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
        followRedirects: false,
        maxRedirects: 0,
      ),
    )
    ..httpClientAdapter = IOHttpClientAdapter(
      // Readers dwell on pages longer than dart:io's 15 s default idle timeout;
      // keeping the pooled TLS connection avoids a fresh handshake (2+ RTT) on
      // the next page. No per-host cap here: a transport-level queue could hold
      // a foreground page behind speculative work and bypass the reader's
      // priority admission gate, which owns concurrency.
      createHttpClient: () =>
          HttpClient()..idleTimeout = const Duration(seconds: 60),
    );
}
