import '../../../reader/domain/ebook_locator.dart';

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/komga/komga_client.dart';
import '../../../core/network/komga/komga_models.dart';
import '../../../core/storage/app_database.dart';
import '../../../offline/data/progress_store.dart';
import '../../../offline/domain/progress.dart';
import '../domain/catalogue.dart';
import '../domain/resume_entry.dart';
import 'catalogue_store.dart';
import 'komga_catalogue_remote.dart';

ResumeEntry parseResumeEntry(Object? value, {bool onDeck = false}) {
  final json = jsonObject(value);
  final item = parseCatalogueItem(json, CatalogueKind.book);
  final seriesTitle = json['seriesTitle'];
  if (seriesTitle != null && seriesTitle is! String) {
    throw const FormatException('Invalid series title');
  }
  final progress = onDeck && json['readProgress'] == null
      ? <String, dynamic>{'page': 0, 'completed': false}
      : jsonObject(json['readProgress']);
  final page = requiredInt(progress, 'page');
  final raster = jsonObject(json['media'])['mediaProfile'] == 'DIVINA';
  if (requiredBool(progress, 'completed') ||
      item.deleted ||
      (onDeck ? page != 0 : raster && (page < 1 || page > item.pageCount))) {
    throw const FormatException('Invalid reading shelf book');
  }
  return ResumeEntry(
    item: item,
    seriesTitle: seriesTitle is String && seriesTitle.isNotEmpty
        ? seriesTitle
        : 'Unknown series',
    pageIndex: page > 0 ? page - 1 : 0,
    pageCount: item.pageCount,
    fraction: 0,
    raster: raster,
    pageKnown: page > 0,
    onDeck: onDeck,
  );
}

/// The server shelf is an independent durable read model. It does not create
/// reader manifests or progress intents just because a cover is displayed.
final class ResumeRepository {
  ResumeRepository(this.catalogue, this.client, {required this.isCurrent});
  final CatalogueStore catalogue;
  final KomgaClient client;
  final bool Function() isCurrent;
  AppDatabase get database => catalogue.database;
  String get accountId => catalogue.accountId;
  bool _closed = false;
  CancelToken? _token;
  Future<void>? _refresh;
  DateTime? _lastAttempt;

  Future<Map<String, String?>> _baselines() async => {
    for (final row in await (database.select(
      database.progressHeads,
    )..where((row) => row.accountId.equals(accountId))).get())
      row.bookId: row.baseline,
  };

  Future<void> refresh({bool force = false}) {
    if (_closed || !isCurrent()) return Future.value();
    if (_refresh != null) return _refresh!;
    if (!force &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(seconds: 5)) {
      return Future.value();
    }
    _lastAttempt = DateTime.now();
    return _refresh = _fetch().whenComplete(() => _refresh = null);
  }

  Future<void> _fetch() async {
    final token = _token = CancelToken();
    try {
      final before = await _baselines();
      final (books, onDeck) = await (
        _fetchShelf(token, onDeck: false),
        _fetchShelf(token, onDeck: true),
      ).wait;
      if (_closed || !isCurrent()) return;
      final payload = jsonEncode({
        'books': books,
        'onDeck': onDeck,
        'baselines': before,
      });
      await database.transaction(() async {
        final after = await _baselines();
        // A replay completed while either GET was in flight. Keep the previous
        // complete snapshot until a refresh can observe the acknowledged state.
        if (_closed ||
            !isCurrent() ||
            jsonEncode(before) != jsonEncode(after)) {
          return;
        }
        // An unchanged poll result must not wake every Home watcher.
        final stored = await (database.select(
          database.resumeSnapshots,
        )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();
        if (stored?.payload == payload) return;
        await database
            .into(database.resumeSnapshots)
            .insertOnConflictUpdate(
              ResumeSnapshotsCompanion.insert(
                accountId: accountId,
                payload: payload,
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      });
    } catch (_) {
      // Offline/auth/malformed responses never replace the last complete shelf.
      // Authentication invalidation remains owned by KomgaClient/session.
    } finally {
      if (identical(_token, token)) _token = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchShelf(
    CancelToken token, {
    required bool onDeck,
  }) async {
    final books = <Map<String, dynamic>>[];
    final ids = <String>{};
    int? total, pages;
    for (var page = 0; ; page++) {
      final result = await client.cataloguePage(
        'book',
        jsonObject,
        page: page,
        inProgress: !onDeck,
        onDeck: onDeck,
        cancelToken: token,
      );
      if (result.totalElements > 5000) {
        throw const FormatException('Reading shelf exceeds safety bound');
      }
      total ??= result.totalElements;
      pages ??= result.totalPages;
      if (result.totalElements != total ||
          result.totalPages != pages ||
          result.items.any(
            (book) => !ids.add(parseResumeEntry(book, onDeck: onDeck).item.id),
          )) {
        throw const FormatException('Reading shelf changed during pagination');
      }
      books.addAll(result.items);
      if (books.length > total ||
          (result.last && books.length != total) ||
          (!result.last && page + 1 >= pages)) {
        throw const FormatException('Incomplete reading shelf');
      }
      if (result.last) break;
    }
    return books;
  }

  Stream<List<ResumeEntry>> watch() => catalogue
      .watchReadingChanges(includeServerShelf: true)
      .asyncMap((_) => _read());

  /// Local reading writes re-run [_read] often (each page turn while the
  /// reader is open), but the server shelf payload changes only on refresh.
  /// Decode/parse it once per distinct payload.
  String? _parsedPayload;
  ({Map<String, dynamic> captured, Map<String, ResumeEntry> entries})?
  _parsedShelf;

  ({Map<String, dynamic> captured, Map<String, ResumeEntry> entries}) _parse(
    String payload,
  ) {
    if (_parsedShelf != null && _parsedPayload == payload) {
      return _parsedShelf!;
    }
    final snapshot = jsonObject(jsonDecode(payload));
    final entries = <String, ResumeEntry>{};
    for (final book in snapshot['books'] as List) {
      final entry = parseResumeEntry(book);
      entries[entry.item.id] = entry;
    }
    for (final book in snapshot['onDeck'] as List? ?? const []) {
      final entry = parseResumeEntry(book, onDeck: true);
      entries.putIfAbsent(entry.item.id, () => entry);
    }
    _parsedPayload = payload;
    return _parsedShelf = (
      captured: jsonObject(snapshot['baselines']),
      entries: Map.unmodifiable(entries),
    );
  }

  Future<List<ResumeEntry>> _read() => database.transaction(() async {
    final cached = await (database.select(
      database.resumeSnapshots,
    )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();
    final local = await catalogue.readResume();
    if (cached == null) return catalogue.visibleResume(local);
    final (:captured, entries: parsed) = _parse(cached.payload);
    final entries = Map.of(parsed);
    final serverTitles = {
      for (final entry in entries.values)
        if (entry.item.seriesId != null)
          entry.item.seriesId!: entry.seriesTitle,
    };
    final localById = {for (final entry in local) entry.item.id: entry};
    final pending = await ProgressStore(database, accountId).pending();
    final latest = {for (final event in pending) event.bookId: event};
    for (final event in latest.values) {
      if (event.operation == ProgressOperation.markUnread ||
          event.operation == ProgressOperation.complete ||
          (event.documentLocator == null
              ? event.pageIndex >= event.pageCount - 1
              : EbookLocator.decode(event.documentLocator!).total >= .99)) {
        entries.remove(event.bookId);
      } else {
        final entry = localById[event.bookId];
        if (entry != null) entries[event.bookId] = entry;
      }
    }
    // Bridge an acknowledged write until the next server shelf arrives. Version
    // equality is used only to detect a local change, never to order clocks.
    for (final head in (await _baselines()).entries) {
      if (latest.containsKey(head.key) ||
          head.value == null ||
          captured[head.key] == head.value) {
        continue;
      }
      final baseline = ProgressSnapshot.decode(head.value!);
      if (baseline.completed || baseline.pageIndex == null) {
        entries.remove(head.key);
      } else {
        final entry = baseline.documentLocator != null
            ? localById[head.key] ?? entries[head.key]
            : entries[head.key] ?? localById[head.key];
        if (entry != null && baseline.pageIndex! < entry.pageCount) {
          entries[head.key] = ResumeEntry(
            item: entry.item,
            pageIndex: baseline.pageIndex!,
            pageCount: entry.pageCount,
            fraction: 0,
            raster: entry.raster,
            totalProgression: baseline.documentLocator == null
                ? entry.totalProgression
                : EbookLocator.decode(baseline.documentLocator!).total,
          );
        }
      }
    }
    final activeSeries = {
      for (final entry in entries.values)
        if (!entry.onDeck) entry.readingIdentity,
    };
    entries.removeWhere(
      (_, entry) =>
          entry.onDeck && activeSeries.contains(entry.readingIdentity),
    );
    final titles = await catalogue.resumeSeriesTitles({
      for (final entry in entries.values)
        if (entry.item.seriesId != null) entry.item.seriesId!,
    });
    return catalogue.visibleResume([
      for (final entry in entries.values)
        ResumeEntry(
          item: entry.item,
          seriesTitle:
              titles[entry.item.seriesId] ??
              serverTitles[entry.item.seriesId] ??
              entry.seriesTitle,
          pageIndex: entry.pageIndex,
          pageCount: entry.pageCount,
          fraction: entry.fraction,
          totalProgression: entry.totalProgression,
          raster: entry.raster,
          pageKnown: entry.pageKnown,
          onDeck: entry.onDeck,
        ),
    ]);
  });

  void close() {
    _closed = true;
    _token?.cancel();
  }
}
