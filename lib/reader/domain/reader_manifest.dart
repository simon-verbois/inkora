import '../../core/errors/failure_kind.dart';
import 'content_key.dart';

final class ReaderFailure implements Exception {
  const ReaderFailure(this.kind, this.message);
  final FailureKind kind;
  final String message;
  @override
  String toString() => message;
}

final class PageDimensions {
  PageDimensions(this.width, this.height, {this.sizeBytes = 0}) {
    if (width < 1 ||
        height < 1 ||
        width > 100000 ||
        height > 100000 ||
        sizeBytes < 0) {
      throw const FormatException('Invalid page dimensions');
    }
  }
  final int width;
  final int height;
  final int sizeBytes;
  double get aspectRatio => width / height;
  Map<String, Object> toJson() => {
    'width': width,
    'height': height,
    'sizeBytes': sizeBytes,
  };
  factory PageDimensions.fromJson(Map<String, dynamic> json) => PageDimensions(
    json['width'] as int,
    json['height'] as int,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
  );
}

final class ReaderManifest {
  ReaderManifest({
    required this.accountId,
    required this.bookId,
    required this.revision,
    required this.title,
    required List<PageDimensions> pages,
    this.libraryId,
    this.seriesId,
    this.documentType,
    this.positions = const [],
  }) : pages = List.unmodifiable(pages) {
    if (accountId.isEmpty ||
        bookId.isEmpty ||
        revision.isEmpty ||
        pages.isEmpty ||
        pages.length > 20000) {
      throw const FormatException('Invalid raster manifest');
    }
  }
  final String accountId;
  final String bookId;
  final String revision;
  final String title;
  final String? libraryId;
  final String? seriesId;
  final List<PageDimensions> pages;
  final String? documentType;
  final List<Map<String, dynamic>> positions;
  bool get isDocument => documentType != null;
  int get assetCount => isDocument ? 1 : pages.length;
  int get maximumAssetBytes =>
      isDocument ? 512 * 1024 * 1024 : 32 * 1024 * 1024;
  ContentKey key(int index) {
    if (index < 0 || index >= pages.length) {
      throw RangeError.index(index, pages);
    }
    return ContentKey(
      accountId: accountId,
      bookId: bookId,
      revision: revision,
      pageIndex: index,
      representation: documentType ?? 'raster-v1',
    );
  }

  void checkKey(ContentKey key) {
    if (key.accountId != accountId ||
        key.bookId != bookId ||
        key.revision != revision ||
        key.representation != (documentType ?? 'raster-v1')) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Page identity no longer matches this book.',
      );
    }
    if (key.pageIndex < 0 || key.pageIndex >= pages.length) {
      throw RangeError.index(key.pageIndex, pages);
    }
  }

  Map<String, Object?> toJson({bool includePositions = true}) => {
    'accountId': accountId,
    'bookId': bookId,
    'revision': revision,
    'title': title,
    'libraryId': libraryId,
    'seriesId': seriesId,
    'documentType': documentType,
    if (includePositions && positions.isNotEmpty) 'positions': positions,
    if (isDocument) 'positionCount': pages.length,
    'pages': (isDocument ? pages.take(1) : pages)
        .map((p) => p.toJson())
        .toList(),
  };
  factory ReaderManifest.fromJson(Map<String, dynamic> json) => ReaderManifest(
    accountId: json['accountId'] as String,
    bookId: json['bookId'] as String,
    revision: json['revision'] as String,
    title: json['title'] as String,
    libraryId: json['libraryId'] as String?,
    seriesId: json['seriesId'] as String?,
    documentType: json['documentType'] as String?,
    positions: (json['positions'] as List? ?? const [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList(),
    pages: json['documentType'] != null && json['positionCount'] is int
        ? [
            for (
              var i = 0;
              i < (json['positionCount'] as int).clamp(1, 20000);
              i++
            )
              PageDimensions(
                1,
                1,
                sizeBytes: i == 0
                    ? ((json['pages'] as List).first as Map)['sizeBytes'] as int
                    : 0,
              ),
          ]
        : (json['pages'] as List)
              .map(
                (p) => PageDimensions.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList(),
  );
}

final class ReaderLocator {
  ReaderLocator(this.pageIndex, [this.fraction = 0, this.documentLocator]) {
    if (pageIndex < 0 || !fraction.isFinite || fraction < 0 || fraction > 1) {
      throw ArgumentError('Invalid reader position');
    }
  }
  final int pageIndex;
  final double fraction;
  final String? documentLocator;
}
