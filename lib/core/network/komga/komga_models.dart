import 'dart:typed_data';

import '../../../features/connection/domain/session.dart';

final class KomgaImage {
  const KomgaImage(
    this.bytes,
    this.mediaType, {
    this.firstByte = Duration.zero,
    this.transfer = Duration.zero,
  });
  final Uint8List bytes;
  final String mediaType;
  final Duration firstByte;
  final Duration transfer;
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

String requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const FormatException('Missing string');
  }
  return value;
}

int requiredInt(Map<String, dynamic> json, String key, {int minimum = 0}) {
  final value = json[key];
  if (value is! int || value < minimum) {
    throw const FormatException('Invalid integer');
  }
  return value;
}

bool requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw const FormatException('Invalid boolean');
  return value;
}

KomgaUser parseUser(Object? value) {
  final json = jsonObject(value);
  final roles = json['roles'];
  if (roles is! List || roles.any((role) => role is! String)) {
    throw const FormatException('Invalid roles');
  }
  return KomgaUser(
    id: requiredString(json, 'id'),
    email: requiredString(json, 'email'),
    roles: Set.unmodifiable(roles.cast<String>()),
  );
}

final class KomgaProgress {
  KomgaProgress.fromJson(Object? value) {
    final json = jsonObject(value);
    pageIndex = requiredInt(json, 'page', minimum: 1) - 1;
    completed = requiredBool(json, 'completed');
  }
  late final int pageIndex;
  late final bool completed;
}

final class KomgaBook {
  KomgaBook.fromJson(Object? value) {
    final json = jsonObject(value);
    id = requiredString(json, 'id');
    name = requiredString(json, 'name');
    pageCount = requiredInt(jsonObject(json['media']), 'pagesCount');
    progress = json['readProgress'] == null
        ? null
        : KomgaProgress.fromJson(json['readProgress']);
  }
  late final String id;
  late final String name;
  late final int pageCount;
  late final KomgaProgress? progress;
}

final class KomgaPage {
  KomgaPage.fromJson(Object? value) {
    final json = jsonObject(value);
    index = requiredInt(json, 'number', minimum: 1) - 1;
    mediaType = requiredString(json, 'mediaType');
    width = requiredInt(json, 'width', minimum: 1);
    height = requiredInt(json, 'height', minimum: 1);
    sizeBytes = requiredInt(json, 'sizeBytes');
  }
  late final int index;
  late final String mediaType;
  late final int width;
  late final int height;
  late final int sizeBytes;
}

final class CataloguePage<T> {
  CataloguePage.fromJson(Object? value, T Function(Object?) parse) {
    final json = jsonObject(value);
    final content = json['content'];
    if (content is! List) throw const FormatException('Invalid page content');
    items = List.unmodifiable(content.map(parse));
    number = requiredInt(json, 'number');
    size = requiredInt(json, 'size', minimum: 1);
    totalElements = requiredInt(json, 'totalElements');
    totalPages = requiredInt(json, 'totalPages');
    last = requiredBool(json, 'last');
    if (items.length > size ||
        requiredInt(json, 'numberOfElements') != items.length ||
        (!last && items.isEmpty)) {
      throw const FormatException('Inconsistent pagination');
    }
  }
  late final List<T> items;
  late final int number;
  late final int size;
  late final int totalElements;
  late final int totalPages;
  late final bool last;
}

/// Evidence is negotiated from advertised operations AND account permissions.
/// Unknown schema/permissions never enable optional reader features.
final class KomgaCapabilities {
  const KomgaCapabilities({
    this.version,
    this.schemaAvailable = false,
    this.pageStreaming = false,
    this.fileDownload = false,
    this.progress = false,
    this.divina = false,
    this.epub = false,
    this.pdf = false,
  });

  factory KomgaCapabilities.fromOpenApi(Object? value, KomgaUser user) {
    final json = jsonObject(value);
    final info = jsonObject(json['info']);
    final paths = jsonObject(json['paths']);
    bool has(String path, String method) {
      final operation = paths[path];
      return operation is Map<String, dynamic> && operation[method] is Map;
    }

    const book = '/api/v1/books/{bookId}';
    final streaming =
        user.roles.contains('PAGE_STREAMING') &&
        has('$book/pages/{pageNumber}', 'get');
    return KomgaCapabilities(
      version: requiredString(info, 'version'),
      schemaAvailable: true,
      pageStreaming: streaming,
      fileDownload:
          user.roles.contains('FILE_DOWNLOAD') && has('$book/file', 'get'),
      progress:
          has('$book/read-progress', 'patch') &&
          has('$book/read-progress', 'delete'),
      divina: streaming && has('$book/manifest/divina', 'get'),
      epub: streaming && has('$book/manifest/epub', 'get'),
      pdf: streaming && has('$book/manifest/pdf', 'get'),
    );
  }

  final String? version;
  final bool schemaAvailable;
  final bool pageStreaming;
  final bool fileDownload;
  final bool progress;
  final bool divina;
  final bool epub;
  final bool pdf;
}
