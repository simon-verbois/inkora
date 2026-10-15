import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/errors/failure_kind.dart';
import '../../core/network/komga/api_failure.dart';
import '../../core/network/komga/komga_client.dart';
import '../../core/network/komga/komga_models.dart';
import '../domain/content_key.dart';
import '../domain/page_source.dart';
import '../domain/reader_manifest.dart';
import 'reader_asset_store.dart';
import 'page_network_gate.dart';
import '../domain/prefetch_policy.dart';

final class KomgaReaderRemote implements BudgetedPageSource {
  KomgaReaderRemote(this.client, this.manifest);
  final KomgaClient client;
  final ReaderManifest manifest;

  static Future<ReaderManifest> loadManifest(
    KomgaClient client,
    String accountId,
    String bookId,
    CancelToken token, {
    void Function(Map<String, dynamic>)? onBook,
  }) async {
    final book = await client.bookDetails(
      bookId,
      jsonObject,
      cancelToken: token,
    );
    if (requiredString(book, 'id') != bookId) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Book identity does not match.',
      );
    }
    final media = jsonObject(book['media']);
    final type = media['mediaType'];
    if (media['status'] == 'READY' &&
        book['deleted'] != true &&
        (type == 'application/epub+zip' || type == 'application/pdf')) {
      final positions = type == 'application/epub+zip'
          ? await client.ebookPositions(bookId, cancelToken: token)
          : <Map<String, dynamic>>[];
      final count = type == 'application/epub+zip'
          ? positions.length
          : requiredInt(media, 'pagesCount', minimum: 1);
      if (count > 20000) {
        throw const FormatException('Document exceeds position budget');
      }
      final size = requiredInt(book, 'sizeBytes', minimum: 1);
      if (size > 512 * 1024 * 1024) {
        throw const FormatException('Document exceeds download budget');
      }
      if ((book['fileHash'] as String? ?? '').isEmpty &&
          (book['fileLastModified'] as String? ?? '').isEmpty) {
        throw const FormatException('Missing document revision');
      }
      onBook?.call(book);
      return ReaderManifest(
        accountId: accountId,
        bookId: bookId,
        revision: sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  book['fileHash'],
                  book['fileLastModified'],
                  size,
                  type,
                  count,
                ]),
              ),
            )
            .toString(),
        title: requiredString(jsonObject(book['metadata']), 'title'),
        libraryId: requiredString(book, 'libraryId'),
        seriesId: requiredString(book, 'seriesId'),
        documentType: type as String,
        positions: positions,
        pages: [
          for (var i = 0; i < count; i++)
            PageDimensions(1, 1, sizeBytes: i == 0 ? size : 0),
        ],
      );
    }
    if (book['deleted'] == true ||
        media['status'] != 'READY' ||
        media['mediaProfile'] != 'DIVINA') {
      throw const ReaderFailure(
        FailureKind.notFound,
        'This book has no supported raster pages.',
      );
    }
    final pages = await client.pages(bookId, cancelToken: token);
    if (pages.length != requiredInt(media, 'pagesCount', minimum: 1)) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Book page count changed. Refresh and retry.',
      );
    }
    final hash = book['fileHash'];
    final modified = book['fileLastModified'];
    if ((hash is! String || hash.isEmpty) &&
        (modified is! String || modified.isEmpty)) {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Book has no stable content revision.',
      );
    }
    final revision = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              book['fileHash'],
              book['fileLastModified'],
              book['sizeBytes'],
              pages.map((p) => [p.width, p.height, p.sizeBytes]).toList(),
            ]),
          ),
        )
        .toString();
    final metadata = jsonObject(book['metadata']);
    onBook?.call(book);
    return ReaderManifest(
      accountId: accountId,
      bookId: bookId,
      revision: revision,
      title: requiredString(metadata, 'title'),
      libraryId: requiredString(book, 'libraryId'),
      seriesId: requiredString(book, 'seriesId'),
      pages: pages
          .map((p) => PageDimensions(p.width, p.height, sizeBytes: p.sizeBytes))
          .toList(),
    );
  }

  @override
  Future<EncodedPage> read(
    ContentKey key, {
    required CancellationSignal cancellation,
  }) => readWithinBudget(
    key,
    cancellation: cancellation,
    maximumBytes: maximumEncodedPageBytes,
  );

  @override
  Future<EncodedPage> readWithinBudget(
    ContentKey key, {
    required CancellationSignal cancellation,
    required int maximumBytes,
  }) async {
    manifest.checkKey(key);
    if (cancellation.isCancelled) {
      throw const ReaderFailure(
        FailureKind.cancelled,
        'Page loading cancelled.',
      );
    }
    CancelToken? ownedToken = CancelToken();
    final token = ownedToken;
    cancellation.whenCancelled.then((_) => ownedToken?.cancel());
    try {
      final image = await client.pageImage(
        key.bookId,
        key.pageIndex,
        cancelToken: token,
        maximumBytes: maximumBytes,
      );
      if (cancellation.isCancelled) {
        throw const ReaderFailure(
          FailureKind.cancelled,
          'Page loading cancelled.',
        );
      }
      validateRaster(image.bytes, image.mediaType);
      return EncodedPage(
        key: key,
        bytes: image.bytes,
        mediaType: image.mediaType,
        networkSample: NetworkSample(
          image.firstByte,
          image.transfer,
          image.bytes.length,
        ),
      );
    } on ApiFailure catch (error) {
      throw ReaderFailure(error.kind, error.message);
    } finally {
      ownedToken = null;
    }
  }
}
