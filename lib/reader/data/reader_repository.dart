import 'package:dio/dio.dart';

import '../../core/errors/failure_kind.dart';
import '../../core/network/komga/api_failure.dart';
import '../../core/network/komga/komga_client.dart';
import '../domain/reader_manifest.dart';
import '../domain/ebook_locator.dart';
import '../../core/network/komga/komga_models.dart';
import '../../offline/data/progress_store.dart';
import '../../offline/domain/progress.dart';
import '../domain/content_key.dart';
import '../domain/page_source.dart';
import '../domain/reader_telemetry.dart';
import 'komga_reader_remote.dart';
import 'reader_asset_store.dart';
import 'reader_store.dart';
import 'tiered_page_source.dart';
import 'encoded_page_cache.dart';
import 'prefetch_session.dart';
import '../domain/prefetch_policy.dart';
import '../../features/library/data/catalogue_store.dart';
import '../../features/library/domain/catalogue.dart';

final class OpenReader {
  const OpenReader(
    this.manifest,
    this.source,
    this.locator, {
    this.offline = false,
    this.prefetch,
    this.telemetry,
  });
  final ReaderManifest manifest;
  final PageSource source;
  final ReaderLocator locator;
  final bool offline;
  final PrefetchSession? prefetch;
  final ReaderTelemetry? telemetry;
}

final class ReaderRepository {
  ReaderRepository(
    this.store,
    this.assets,
    this.client,
    this.gate, {
    required this.isCurrent,
  });
  final ReaderStore store;
  final ReaderAssetStore assets;
  final KomgaClient client;
  final PageNetworkGate gate;
  final bool Function() isCurrent;
  final memory = EncodedPageCache();
  final _prefetches = <PrefetchSession>{};
  final _tokens = <CancelToken>{};
  final _sources = <ContentKey, _ReaderSourceRef>{};
  bool _closed = false;
  void _check() {
    if (_closed || !isCurrent()) {
      throw const ReaderFailure(
        FailureKind.cancelled,
        'Reader session closed.',
      );
    }
  }

  Future<OpenReader> open(
    String bookId, {
    bool refresh = false,
    CancellationSignal? cancellation,
    PagePriority priority = PagePriority.visible,
  }) async {
    _check();
    final saved = await store.manifest(bookId);
    if (saved != null && !refresh && !await store.hasServerResume(bookId)) {
      return _opened(saved, offline: false);
    }
    final token = CancelToken();
    _tokens.add(token);
    if (cancellation?.isCancelled ?? false) token.cancel();
    cancellation?.whenCancelled.then((_) {
      if (_tokens.contains(token)) token.cancel();
    });
    ReaderManifest manifest;
    Map<String, dynamic>? bookSnapshot;
    var offline = false;
    final admission = PageRequest(priority: priority);
    final signal = CancellationController();
    token.whenCancel.then((_) => signal.cancel());
    var admitted = false;
    try {
      await gate.acquire(signal, admission);
      admitted = true;
      manifest = await KomgaReaderRemote.loadManifest(
        client,
        store.accountId,
        bookId,
        token,
        onBook: (value) => bookSnapshot = value,
      );
      _check();
      await store.saveManifest(manifest);
      final progress = bookSnapshot?['readProgress'];
      try {
        final ebook = manifest.documentType == 'application/epub+zip'
            ? await client.ebookProgression(bookId, cancelToken: token)
            : null;
        final rawLocator = ebook == null ? null : jsonObject(ebook['locator']);
        final docLocator =
            rawLocator == null || (rawLocator['href'] as String? ?? '').isEmpty
            ? null
            : EbookLocator(rawLocator);
        final snapshot = manifest.documentType == 'application/epub+zip'
            ? ProgressSnapshot(
                revision: manifest.revision,
                pageIndex: docLocator?.positionIn(manifest.positions),
                completed: (docLocator?.total ?? 0) >= 0.99,
                version: ebook?['modified'] as String?,
                documentLocator: docLocator?.encode(),
              )
            : progress == null
            ? ProgressSnapshot(revision: manifest.revision)
            : ProgressSnapshot(
                revision: manifest.revision,
                pageIndex:
                    requiredInt(jsonObject(progress), 'page', minimum: 1) - 1,
                completed: requiredBool(jsonObject(progress), 'completed'),
                version: jsonObject(progress)['lastModified'] as String?,
              );
        await ProgressStore(
          store.database,
          store.accountId,
        ).seedServerLocator(manifest, snapshot);
      } on FormatException {
        /* Invalid optional progress cannot block raster reading. */
      } on TypeError {
        /* Keep local position if the optional DTO is malformed. */
      } on RangeError {
        /* A changed/inconsistent remote locator is not imported. */
      }
    } on ApiFailure catch (error) {
      if (saved == null || !error.allowsOfflineRestore) {
        throw ReaderFailure(error.kind, error.message);
      }
      manifest = saved;
      offline = true;
    } on FormatException {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Invalid book manifest.',
      );
    } on TypeError {
      throw const ReaderFailure(
        FailureKind.corruptContent,
        'Invalid book manifest.',
      );
    } finally {
      if (admitted) gate.release(admission);
      _tokens.remove(token);
    }
    _check();
    return _opened(manifest, offline: offline);
  }

  Future<OpenReader> _opened(
    ReaderManifest manifest, {
    required bool offline,
  }) async {
    for (final prefetch in _prefetches.toList()) {
      if (prefetch.manifest.bookId == manifest.bookId &&
          prefetch.manifest.revision != manifest.revision) {
        prefetch.close();
        _prefetches.remove(prefetch);
      }
    }
    for (final key in _sources.keys.toList()) {
      if (key.bookId == manifest.bookId && key.revision != manifest.revision) {
        _sources.remove(key)!.source.close();
      }
    }
    memory.retainRevision(
      manifest.accountId,
      manifest.bookId,
      manifest.revision,
    );
    final locator = await store.locator(manifest);
    _check();
    final key = manifest.key(0);
    final owned = _sources.putIfAbsent(
      key,
      () => _ReaderSourceRef(
        TieredPageSource(
          manifest,
          assets,
          KomgaReaderRemote(client, manifest),
          gate,
          memory: memory,
        ),
      ),
    );
    owned.readers++;
    final source = owned.source;
    final prefetch = PrefetchSession(
      manifest,
      source,
      PrefetchPolicy(gate.estimate),
      memory,
      prepareNext: (cancellation) async {
        final next = await nextChapterId(manifest);
        _check();
        if (next == null) return null;
        final reader = await open(
          next,
          cancellation: cancellation,
          priority: PagePriority.chapter,
        );
        return ChapterAhead(
          reader.manifest,
          reader.source as PrioritizedPageSource,
          () => release(reader),
        );
      },
    );
    _prefetches.add(prefetch);
    return OpenReader(
      manifest,
      source,
      locator,
      offline: offline,
      prefetch: prefetch,
      telemetry: ReaderTelemetry(),
    );
  }

  /// Account snapshot order/availability only; no arithmetic on remote IDs.
  /// Callers with reading-list context can explicitly pass its query.
  Future<String?> nextChapterId(
    ReaderManifest manifest, {
    CatalogueQuery? order,
  }) async {
    _check();
    if (manifest.accountId != store.accountId ||
        (order == null && manifest.seriesId == null)) {
      return null;
    }
    final query =
        order ??
        CatalogueQuery(
          kind: CatalogueKind.book,
          seriesId: manifest.seriesId,
          sort: CatalogueSort.sequence,
        );
    if (query.kind != CatalogueKind.book ||
        query.sort != CatalogueSort.sequence) {
      throw ArgumentError('Chapter handoff needs verified book sequence');
    }
    final catalogue = CatalogueStore(store.database, store.accountId);
    var found = false;
    // Include unavailable entries: never speculate across an inaccessible chapter.
    for (var page = 0; ; page++) {
      final result = await catalogue.read(
        CatalogueQuery(
          kind: query.kind,
          seriesId: query.seriesId,
          groupKind: query.groupKind,
          groupId: query.groupId,
          sort: query.sort,
          page: page,
          pageSize: 200,
        ),
      );
      _check();
      for (final book in result.items) {
        if (found) return book.canOpen ? book.id : null;
        if (book.id == manifest.bookId) found = book.canOpen;
      }
      if ((page + 1) * 200 >= result.total) return null;
    }
  }

  void release(OpenReader reader) {
    reader.prefetch?.close();
    _prefetches.remove(reader.prefetch);
    if (reader.source case final TieredPageSource source) {
      final key = reader.manifest.key(0);
      final owned = _sources[key];
      if (owned != null &&
          identical(owned.source, source) &&
          --owned.readers == 0) {
        source.close();
        _sources.remove(key);
      }
    }
  }

  void close() {
    _closed = true;
    for (final prefetch in _prefetches.toList()) {
      prefetch.close();
    }
    _prefetches.clear();
    memory.clear();
    for (final token in _tokens) {
      token.cancel();
    }
    for (final owned in _sources.values) {
      owned.source.close();
    }
    _tokens.clear();
    _sources.clear();
  }
}

final class _ReaderSourceRef {
  _ReaderSourceRef(this.source);
  final TieredPageSource source;
  int readers = 0;
}
