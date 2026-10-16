import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../features/connection/domain/session.dart';
import '../../errors/failure_kind.dart';
import '../http_client.dart';
import '../server_endpoint.dart';
import 'api_failure.dart';
import 'komga_models.dart';

final class KomgaClient {
  KomgaClient(this.endpoint, Credentials credentials, {Dio? dio})
    : _dio = dio ?? createHttpClient(endpoint) {
    _dio.options.headers.addAll(credentials.headers);
    _dio.options.followRedirects = false;
    _dio.options.maxRedirects = 0;
    if (credentials.method == AuthenticationMethod.basic) {
      _dio.interceptors.add(_SessionTokenInterceptor(_dio));
    }
  }

  final ServerEndpoint endpoint;
  final Dio _dio;
  final _requests = <CancelToken>{};
  bool _closed = false;
  void Function()? onUnauthorized;

  Future<T> _request<T>(
    String path,
    FutureOr<T> Function(Object?) parse, {
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    ResponseType? responseType,
    Map<String, dynamic>? headers,
    bool acceptNotModified = false,
    void Function(Response<Object?>)? onResponse,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (_closed) {
      token.cancel();
    }
    _requests.add(token);
    try {
      final response = await _dio.request<Object?>(
        endpoint.resolveApiPath(path).toString(),
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          responseType: responseType,
          headers: headers,
          validateStatus: acceptNotModified
              ? (status) =>
                    status != null &&
                    (status >= 200 && status < 300 || status == 304)
              : null,
        ),
        cancelToken: token,
      );
      onResponse?.call(response);
      return await parse(response.data);
    } on DioException catch (error) {
      final failure = ApiFailure.fromDio(error);
      if (failure.kind == FailureKind.authentication) onUnauthorized?.call();
      throw failure;
    } on FormatException {
      throw const ApiFailure(
        FailureKind.corruptContent,
        'Invalid server response.',
      );
    } on TypeError {
      throw const ApiFailure(
        FailureKind.corruptContent,
        'Invalid server response.',
      );
    } finally {
      _requests.remove(token);
    }
  }

  Future<KomgaUser> currentUser() => _request('api/v2/users/me', parseUser);

  Future<KomgaCapabilities> negotiateCapabilities(KomgaUser user) async {
    try {
      return await _request(
        'v3/api-docs',
        (json) => KomgaCapabilities.fromOpenApi(json, user),
      );
    } on ApiFailure catch (error) {
      if (error.kind == FailureKind.authentication ||
          error.kind == FailureKind.cancelled) {
        rethrow;
      }
      return const KomgaCapabilities();
    }
  }

  Future<CataloguePage<KomgaBook>> books({
    int page = 0,
    int size = 20,
    CancelToken? cancelToken,
  }) async {
    if (page < 0 || size < 1 || size > 500) {
      throw ArgumentError('Invalid pagination');
    }
    final result = await _request(
      'api/v1/books',
      (json) => CataloguePage<KomgaBook>.fromJson(json, KomgaBook.fromJson),
      query: {'page': page, 'size': size, 'sort': 'id,asc'},
      cancelToken: cancelToken,
    );
    if (result.number != page) {
      throw const ApiFailure(
        FailureKind.corruptContent,
        'Unexpected catalogue page.',
      );
    }
    return result;
  }

  Future<List<T>> catalogueLibraries<T>(
    T Function(Object?) parse, {
    CancelToken? cancelToken,
  }) => _request('api/v1/libraries', (json) {
    if (json is! List) throw const FormatException('Invalid libraries');
    return json.map(parse).toList(growable: false);
  }, cancelToken: cancelToken);

  Future<CataloguePage<T>> cataloguePage<T>(
    String kind,
    T Function(Object?) parse, {
    int page = 0,
    int size = 200,
    CancelToken? cancelToken,
    bool inProgress = false,
    bool onDeck = false,
    bool parseInBackground = false,
  }) async {
    final resource = switch (kind) {
      'series' => 'series',
      'book' => 'books',
      'collection' => 'collections',
      'readlist' => 'readlists',
      _ => throw ArgumentError('Unsupported catalogue kind'),
    };
    if (page < 0 || size < 1 || size > 500) {
      throw ArgumentError('Invalid pagination');
    }
    if (onDeck && (kind != 'book' || inProgress)) {
      throw ArgumentError('Invalid on-deck query');
    }
    final result = await _request<CataloguePage<T>>(
      'api/v1/$resource${onDeck ? '/ondeck' : ''}',
      parseInBackground
          ? (body) => _parsePageInBackground(body, parse)
          : (json) => CataloguePage<T>.fromJson(json, parse),
      // Bytes: Dio forces JSON decoding for non-String result types otherwise.
      responseType: parseInBackground ? ResponseType.bytes : null,
      query: {
        'page': page,
        'size': size,
        if (!onDeck)
          'sort': inProgress ? 'readProgress.lastModified,desc' : 'id,asc',
        if (inProgress) 'read_status': 'IN_PROGRESS',
      },
      cancelToken: cancelToken,
    );
    if (result.number != page) {
      throw const ApiFailure(
        FailureKind.corruptContent,
        'Unexpected catalogue page.',
      );
    }
    return result;
  }

  String _bookPath(String bookId) {
    if (bookId.isEmpty || bookId == '.' || bookId == '..') {
      throw ArgumentError('Invalid book ID');
    }
    return 'api/v1/books/${Uri.encodeComponent(bookId)}';
  }

  Future<KomgaBook> book(String id) =>
      _request(_bookPath(id), KomgaBook.fromJson);

  /// Poster contracts verified in the pinned Komga 1.28.1 OpenAPI.
  Future<Uint8List> thumbnail(
    String kind,
    String id, {
    required CancelToken cancelToken,
    int maximumBytes = 2 * 1024 * 1024,
  }) async => (await thumbnailResult(
    kind,
    id,
    cancelToken: cancelToken,
    maximumBytes: maximumBytes,
  )).bytes!;

  Future<({Uint8List? bytes, String? etag})> thumbnailResult(
    String kind,
    String id, {
    required CancelToken cancelToken,
    int maximumBytes = 2 * 1024 * 1024,
    String? etag,
  }) {
    final resource = switch (kind) {
      'book' => 'books',
      'series' => 'series',
      _ => throw ArgumentError('Unsupported poster kind'),
    };
    if (id.isEmpty || id == '.' || id == '..' || maximumBytes < 1) {
      throw ArgumentError('Invalid poster request');
    }
    String? receivedEtag;
    var notModified = false;
    return _request(
      'api/v1/$resource/${Uri.encodeComponent(id)}/thumbnail',
      (value) async {
        if (notModified) {
          if (value is ResponseBody) await value.stream.drain<void>();
          return (bytes: null, etag: receivedEtag ?? etag);
        }
        if (value is! ResponseBody) {
          throw const FormatException('Invalid poster stream');
        }
        final media = value.headers['content-type']?.firstOrNull
            ?.split(';')
            .first
            .toLowerCase();
        if (!const {
          'image/jpeg',
          'image/png',
          'image/webp',
          'image/gif',
        }.contains(media)) {
          throw const FormatException('Unsupported poster media');
        }
        final length = int.tryParse(
          value.headers['content-length']?.firstOrNull ?? '',
        );
        if (length != null && length > maximumBytes) {
          cancelToken.cancel();
          throw const FormatException('Poster exceeds byte budget');
        }
        final bytes = BytesBuilder(copy: false);
        final chunks = StreamIterator(value.stream);
        final cancelled = cancelToken.whenCancel.then<bool>(
          (error) => throw error,
        );
        try {
          while (await Future.any([chunks.moveNext(), cancelled])) {
            final chunk = chunks.current;
            if (cancelToken.isCancelled) {
              throw const ApiFailure(
                FailureKind.cancelled,
                'Poster cancelled.',
              );
            }
            if (bytes.length + chunk.length > maximumBytes) {
              cancelToken.cancel();
              throw const FormatException('Poster exceeds byte budget');
            }
            bytes.add(chunk);
          }
        } finally {
          await chunks.cancel();
        }
        if (cancelToken.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled, 'Poster cancelled.');
        }
        if (bytes.length == 0 || (length != null && length != bytes.length)) {
          throw const FormatException('Incomplete poster');
        }
        return (bytes: bytes.takeBytes(), etag: receivedEtag);
      },
      cancelToken: cancelToken,
      responseType: ResponseType.stream,
      headers: {
        'Accept': 'image/jpeg,image/png,image/webp,image/gif',
        'Cache-Control': 'no-cache',
        'If-None-Match': ?etag,
      },
      acceptNotModified: etag != null,
      onResponse: (response) {
        notModified = response.statusCode == 304;
        receivedEtag = response.headers.value('etag');
      },
    );
  }

  Future<T> bookDetails<T>(
    String id,
    T Function(Object?) parse, {
    CancelToken? cancelToken,
  }) => _request(_bookPath(id), parse, cancelToken: cancelToken);

  Future<List<KomgaPage>> pages(String id, {CancelToken? cancelToken}) =>
      _request('${_bookPath(id)}/pages', (value) {
        if (value is! List) throw const FormatException('Invalid pages');
        final pages = value.map(KomgaPage.fromJson).toList(growable: false);
        for (var i = 0; i < pages.length; i++) {
          if (pages[i].index != i) {
            throw const FormatException('Unexpected page numbering');
          }
        }
        return pages;
      }, cancelToken: cancelToken);

  Future<KomgaImage> pageImage(
    String id,
    int index, {
    required CancelToken cancelToken,
    int maximumBytes = 32 * 1024 * 1024,
  }) {
    if (index < 0 || maximumBytes < 1) {
      throw ArgumentError('Invalid page request');
    }
    final timer = Stopwatch()..start();
    return _request(
      '${_bookPath(id)}/pages/${index + 1}',
      (value) async {
        if (value is! ResponseBody) {
          throw const FormatException('Invalid image stream');
        }
        final mediaType = (value.headers['content-type']?.firstOrNull ?? '')
            .split(';')
            .first
            .toLowerCase();
        final length = int.tryParse(
          value.headers['content-length']?.firstOrNull ?? '',
        );
        if (length != null && length > maximumBytes) {
          cancelToken.cancel();
          throw const FormatException('Page exceeds encoded byte budget');
        }
        final builder = BytesBuilder(copy: false);
        Duration? firstByte;
        await for (final chunk in value.stream) {
          if (cancelToken.isCancelled) {
            throw const ApiFailure(FailureKind.cancelled, 'Request cancelled.');
          }
          if (builder.length + chunk.length > maximumBytes) {
            cancelToken.cancel();
            throw const FormatException('Page exceeds encoded byte budget');
          }
          firstByte ??= timer.elapsed;
          builder.add(chunk);
        }
        if (cancelToken.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled, 'Request cancelled.');
        }
        return KomgaImage(
          builder.takeBytes(),
          mediaType,
          firstByte: firstByte ?? timer.elapsed,
          transfer: timer.elapsed - (firstByte ?? timer.elapsed),
        );
      },
      responseType: ResponseType.stream,
      headers: {'Accept': 'image/jpeg,image/png,image/webp,image/gif'},
      cancelToken: cancelToken,
    );
  }

  Future<({String mediaType, int byteLength})> pageToFile(
    String id,
    int index,
    File file, {
    required CancelToken cancelToken,
    required int maximumBytes,
    bool original = false,
    void Function(int received, int total)? onProgress,
  }) => _request(
    original ? '${_bookPath(id)}/file' : '${_bookPath(id)}/pages/${index + 1}',
    (value) async {
      if (value is! ResponseBody) throw const FormatException('Invalid stream');
      final length = int.tryParse(
        value.headers['content-length']?.firstOrNull ?? '',
      );
      if (length != null && length > maximumBytes) {
        cancelToken.cancel();
        throw const FormatException('Download exceeds its byte reservation');
      }
      final sink = await file.open(mode: FileMode.write);
      var count = 0;
      try {
        await for (final chunk in value.stream) {
          if (cancelToken.isCancelled) {
            throw const ApiFailure(
              FailureKind.cancelled,
              'Download cancelled.',
            );
          }
          count += chunk.length;
          if (count > maximumBytes) {
            cancelToken.cancel();
            throw const FormatException(
              'Download exceeds its byte reservation',
            );
          }
          await sink.writeFrom(chunk);
          onProgress?.call(count, length ?? 0);
        }
        if (cancelToken.isCancelled) {
          throw const ApiFailure(FailureKind.cancelled, 'Download cancelled.');
        }
        if (count == 0 || (length != null && count != length)) {
          throw const FormatException('Incomplete download');
        }
        await sink.flush();
        return (
          mediaType: (value.headers['content-type']?.firstOrNull ?? '')
              .split(';')
              .first
              .toLowerCase(),
          byteLength: count,
        );
      } finally {
        await sink.close();
      }
    },
    responseType: ResponseType.stream,
    headers: {
      'Accept': original ? '*/*' : 'image/jpeg,image/png,image/webp,image/gif',
    },
    cancelToken: cancelToken,
  );

  Uri pageUri(String id, int pageIndex) {
    if (pageIndex < 0) throw ArgumentError('Invalid page index');
    return endpoint.resolveApiPath('${_bookPath(id)}/pages/${pageIndex + 1}');
  }

  Future<List<Map<String, dynamic>>> ebookPositions(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    '${_bookPath(id)}/positions',
    (value) async {
      if (value is! List<int>) {
        throw const FormatException('Invalid position response');
      }
      return _parseEbookPositions(value);
    },
    responseType: ResponseType.bytes,
    headers: {'Accept': 'application/vnd.readium.position-list+json'},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>?> ebookProgression(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    '${_bookPath(id)}/progression',
    (value) => value == null || value == '' ? null : jsonObject(value),
    headers: {'Accept': 'application/vnd.readium.progression+json'},
    cancelToken: cancelToken,
  );

  Future<void> updateEbookProgression(
    String id,
    Map<String, dynamic> locator, {
    String? modifiedAfter,
    CancelToken? cancelToken,
  }) => _request(
    '${_bookPath(id)}/progression',
    (_) {},
    method: 'PUT',
    cancelToken: cancelToken,
    data: {
      'modified': _nextProgressionTimestamp(modifiedAfter),
      'device': {'id': 'inkora', 'name': 'Inkora'},
      'locator': locator,
    },
  );

  Future<void> updateProgress(
    String id, {
    int? pageIndex,
    bool? completed,
    CancelToken? cancelToken,
  }) {
    if ((pageIndex == null && completed != true) ||
        (pageIndex != null && pageIndex < 0)) {
      throw ArgumentError('Progress requires a page index or completed=true');
    }
    return _request(
      '${_bookPath(id)}/read-progress',
      (_) {},
      method: 'PATCH',
      cancelToken: cancelToken,
      data: {
        if (pageIndex != null) 'page': pageIndex + 1,
        'completed': ?completed,
      },
    );
  }

  Future<void> resetProgress(String id, {CancelToken? cancelToken}) => _request(
    '${_bookPath(id)}/read-progress',
    (_) {},
    method: 'DELETE',
    cancelToken: cancelToken,
  );

  void close() {
    _closed = true;
    for (final token in _requests.toList()) {
      token.cancel();
    }
    _dio.close(force: true);
  }
}

/// Top-level so the worker closure captures only the body and parser (never
/// the client, its Dio instance or sockets). UTF-8, JSON and DTO mapping all
/// run in the worker; the parsed page returns without a copy (Isolate.exit).
Future<CataloguePage<T>> _parsePageInBackground<T>(
  Object? body,
  T Function(Object?) parse,
) {
  // A transformer that already decoded JSON leaves only the mapping.
  if (body is! List<int>) {
    return Future.value(CataloguePage<T>.fromJson(body, parse));
  }
  return Isolate.run(() {
    try {
      return CataloguePage<T>.fromJson(jsonDecode(utf8.decode(body)), parse);
    } on TypeError {
      throw const FormatException('Invalid catalogue page');
    }
  });
}

/// Komga verifies a Basic password with a deliberately slow hash on every
/// request (measured ~70 ms server time per request on 1.28.1 versus ~3 ms
/// with a session token). Password accounts therefore request a session with
/// an empty `X-Auth-Token` header and then send only the token. An expired or
/// revoked token (401) is replayed once with Basic, which also renews it; a
/// Basic 401 remains a real authentication failure. The token lives only in
/// memory for this client and is never logged or persisted.
final class _SessionTokenInterceptor extends Interceptor {
  _SessionTokenInterceptor(this._dio);
  final Dio _dio;
  String? _token;
  static const _header = 'X-Auth-Token';
  static const _sentToken = 'inkora.sessionToken';
  static const _replayed = 'inkora.sessionReplay';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _token;
    if (token != null && options.extra[_replayed] != true) {
      // A valid token with a wrong/stale Basic header is rejected: send one.
      options.headers.remove('Authorization');
      options.headers[_header] = token;
      options.extra[_sentToken] = token;
    } else {
      options.headers[_header] = '';
    }
    handler.next(options);
  }

  void _capture(Headers headers) {
    final token = headers.value(_header);
    if (token != null &&
        token.isNotEmpty &&
        token.length <= 256 &&
        !token.contains(RegExp(r'[\r\n]'))) {
      _token = token;
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _capture(response.headers);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final sent = error.requestOptions.extra[_sentToken];
    if (error.response?.statusCode != 401 || sent == null) {
      return handler.next(error);
    }
    if (_token == sent) _token = null;
    final options = error.requestOptions
      ..extra[_replayed] = true
      ..extra.remove(_sentToken)
      ..headers.remove(_header)
      ..headers['Authorization'] = _dio.options.headers['Authorization'];
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (replay) {
      handler.next(replay);
    }
  }
}

Future<List<Map<String, dynamic>>> _parseEbookPositions(List<int> bytes) =>
    Isolate.run(() {
      final positions = jsonObject(jsonDecode(utf8.decode(bytes)))['positions'];
      if (positions is! List || positions.isEmpty || positions.length > 20000) {
        throw const FormatException('Invalid ebook positions');
      }
      return positions.map(jsonObject).toList(growable: false);
    });

String _nextProgressionTimestamp(String? observed) {
  final now = DateTime.now().toUtc();
  final previous = observed == null
      ? null
      : DateTime.tryParse(observed)?.toUtc();
  // Komga demands a newer protocol timestamp. Server read-back, rather than
  // ordering device clocks, remains the authority for conflict decisions.
  return (previous != null && !now.isAfter(previous)
          ? previous.add(const Duration(milliseconds: 1))
          : now)
      .toIso8601String();
}
