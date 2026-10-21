import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/komga/komga_models.dart';
import '../../../core/storage/app_database.dart';
import '../../../reader/data/reading_history.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_filters.dart';
import '../domain/reading_history.dart';
import 'catalogue_store.dart';
import 'komga_catalogue_remote.dart';

/// One page of Komga books with read progress, newest progress first.
typedef HistoryPageFetch = Future<CataloguePage<HistoryEntry>> Function(
  int page,
  int size,
  CancelToken token,
);

/// A Komga book DTO with `readProgress` (verified 1.28.1 history query) as a
/// history entry. The timestamp is `readProgress.lastModified`; raster
/// positions become a ratio with the reader's zero-based convention.
HistoryEntry parseServerHistoryEntry(Object? value) {
  final json = jsonObject(value);
  final item = parseCatalogueItem(json, CatalogueKind.book);
  final progress = jsonObject(json['readProgress']);
  final completed = requiredBool(progress, 'completed');
  final at = DateTime.tryParse(requiredString(progress, 'lastModified'));
  if (at == null) throw const FormatException('Invalid progress timestamp');
  final page = progress['page'];
  final raster = jsonObject(json['media'])['mediaProfile'] == 'DIVINA';
  final seriesTitle = json['seriesTitle'];
  return HistoryEntry(
    bookId: item.id,
    title: item.title,
    at: at.toUtc(),
    source: HistorySource.server,
    seriesId: item.seriesId,
    seriesTitle: seriesTitle is String && seriesTitle.isNotEmpty
        ? seriesTitle
        : null,
    libraryId: item.libraryId,
    number: item.number,
    pageCount: item.pageCount,
    mediaType: item.metadata.mediaType,
    modified: item.modified,
    status: completed ? ReadingStatus.completed : ReadingStatus.inProgress,
    ratio: completed
        ? 1
        : raster && page is int && page >= 1 && item.pageCount > 0
        ? ((page - 1) / item.pageCount).clamp(0.0, 1.0)
        : null,
    available: item.canOpen,
  );
}

/// Cached server pages of one account.
@immutable
final class ServerHistory {
  const ServerHistory({this.entries = const [], this.pages = 0, this.more});
  final List<HistoryEntry> entries;
  final int pages;

  /// True when another page exists; null before the first successful fetch.
  final bool? more;

  static const empty = ServerHistory();

  String encode() => jsonEncode({
    'pages': pages,
    'more': more,
    'entries': [for (final entry in entries) entry.toJson()],
  });

  static ServerHistory decode(String payload) {
    final json = jsonObject(jsonDecode(payload));
    return ServerHistory(
      pages: json['pages'] as int? ?? 0,
      more: json['more'] as bool?,
      entries: List.unmodifiable([
        for (final entry in json['entries'] as List? ?? const [])
          HistoryEntry.fromJson(jsonObject(entry)),
      ]),
    );
  }
}

/// What the history screen shows: merged entries, how many device opens
/// exist (Clear is enabled only then) and whether the server has more.
@immutable
final class ReadingHistoryView {
  const ReadingHistoryView({
    this.entries = const [],
    this.deviceCount = 0,
    this.more = false,
  });
  final List<HistoryEntry> entries;
  final int deviceCount;
  final bool more;

  @override
  bool operator ==(Object other) =>
      other is ReadingHistoryView &&
      listEquals(other.entries, entries) &&
      other.deviceCount == deviceCount &&
      other.more == more;
  @override
  int get hashCode => Object.hash(Object.hashAll(entries), deviceCount, more);
}

/// Reading history of one account: this device's reader opens (local
/// ReadingHistory table) merged with Komga read progress (in-progress and
/// read books, newest `readProgress.lastModified` first).
///
/// Server pages are cached per account in app preferences, so offline the
/// screen shows local opens and the last cached server entries. [refresh]
/// fetches the first page (once per screen open; callers do not refresh on
/// rebuilds), [loadMore] appends the next page up to [maxPages]. Requests are
/// coalesced and cancelled on [close]; results are discarded when the
/// account changed meanwhile; an unchanged result is not written.
final class ReadingHistoryRepository {
  ReadingHistoryRepository(
    this.catalogue, {
    required this.isCurrent,
    this.fetch,
    this.pageSize = 50,
    this.maxPages = 10,
    this.deviceLimit = 500,
  });
  final CatalogueStore catalogue;
  final HistoryPageFetch? fetch;
  final bool Function() isCurrent;
  final int pageSize, maxPages, deviceLimit;
  AppDatabase get database => catalogue.database;
  String get accountId => catalogue.accountId;
  String get key => 'reading-history-server:$accountId';

  bool _closed = false;
  CancelToken? _token;
  Future<void>? _work;

  bool get _current => !_closed && isCurrent();

  Future<String?> _payload() async => (await (database.select(
    database.appPreferences,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.payload;

  String? _parsedPayload;
  ServerHistory _parsed = ServerHistory.empty;

  /// Decodes the cached server pages once per distinct payload.
  ServerHistory _server(String? payload) {
    if (payload == null) return ServerHistory.empty;
    if (payload == _parsedPayload) return _parsed;
    try {
      _parsed = ServerHistory.decode(payload);
    } catch (_) {
      _parsed = ServerHistory.empty;
    }
    _parsedPayload = payload;
    return _parsed;
  }

  /// Fetches the newest server page and replaces the cached pages.
  Future<void> refresh() => _run((token) async {
    final page = await fetch!(0, pageSize, token);
    return ServerHistory(
      entries: _unique(page.items),
      pages: 1,
      more: !page.last && maxPages > 1,
    );
  });

  /// Appends the next server page to the cache.
  Future<void> loadMore() => _run((token) async {
    final cached = _server(await _payload());
    if (cached.more != true || cached.pages >= maxPages) return null;
    final page = await fetch!(cached.pages, pageSize, token);
    final pages = cached.pages + 1;
    return ServerHistory(
      entries: _unique([...cached.entries, ...page.items]),
      pages: pages,
      more: !page.last && pages < maxPages,
    );
  });

  static List<HistoryEntry> _unique(Iterable<HistoryEntry> entries) {
    final seen = <String>{};
    return List.unmodifiable([
      for (final entry in entries)
        if (seen.add(entry.bookId)) entry,
    ]);
  }

  Future<void> _run(Future<ServerHistory?> Function(CancelToken) load) {
    if (!_current || fetch == null) return Future.value();
    return _work ??= () async {
      final token = _token = CancelToken();
      try {
        final next = await load(token);
        if (next == null || !_current) return;
        final payload = next.encode();
        await database.transaction(() async {
          if (!_current || await _payload() == payload) return;
          await database
              .into(database.appPreferences)
              .insertOnConflictUpdate(
                AppPreferencesCompanion.insert(key: key, payload: payload),
              );
        });
      } catch (_) {
        // Offline, cancelled or malformed responses keep the cached pages.
      } finally {
        if (identical(_token, token)) _token = null;
        _work = null;
      }
    }();
  }

  /// Merged history, re-read when a device open, the cached server pages,
  /// a catalogue publication or a book's reading classification changes
  /// (not on every page turn). Emits only changed views.
  Stream<ReadingHistoryView> watch() => watchTables(database, {
    database.readingHistory,
    database.appPreferences,
    database.catalogueSnapshots,
    database.bookReadingStates,
  }).asyncMap((_) => read()).distinct();

  Future<ReadingHistoryView> read() async {
    final device = await ReadingHistoryStore(
      database,
      accountId,
    ).recent(deviceLimit);
    final server = _server(await _payload());
    final details = await _details({
      for (final row in device) row.bookId,
      for (final entry in server.entries) entry.bookId,
    });
    final visible = await catalogue.libraryVisibility();
    final local = [
      for (final row in device)
        _withDetails(
          HistoryEntry(
            bookId: row.bookId,
            title: row.title,
            at: row.openedAt.toUtc(),
            source: HistorySource.device,
          ),
          details[row.bookId],
        ),
    ];
    final remote = [
      for (final entry in server.entries)
        _withCatalogue(entry, details[entry.bookId]),
    ];
    final merged = [
      for (final entry in mergeReadingHistory(local, remote))
        if (entry.libraryId == null || visible(entry.libraryId))
          // A device open newer than the server progress shows this device's
          // state and position (pending intents included).
          entry.source == HistorySource.device && details[entry.bookId] != null
              ? _withLocalState(entry, details[entry.bookId]!)
              : entry,
    ];
    return ReadingHistoryView(
      entries: List.unmodifiable(merged),
      deviceCount: device.length,
      more: server.more == true,
    );
  }

  /// Catalogue fields, effective reading state and local position of the
  /// given books in one query (primary-key lookups per book).
  Future<Map<String, _Details>> _details(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await database
        .customSelect(
          '''SELECT q.book_id, e.title, e.series_id, e.library_id, e.number,
            e.page_count, e.modified, e.available, e.deleted,
            json_extract(e.descriptive_metadata, '\$.mediaType') AS media_type,
            p.title AS series_title, r.page_index AS position_page,
            r.fraction AS position_fraction,
            json_extract(r.document_locator, '\$.locations.totalProgression') AS position_total,
            ${CatalogueStore.readingState('q', id: 'book_id', metadata: 'e.descriptive_metadata')} AS reading_state
          FROM (SELECT ? AS account_id, value AS book_id FROM json_each(?)) q
          LEFT JOIN catalogue_snapshots s ON s.account_id=q.account_id
          LEFT JOIN catalogue_entries e ON e.account_id=q.account_id
            AND e.generation=s.generation AND e.kind='book' AND e.remote_id=q.book_id
          LEFT JOIN catalogue_entries p ON p.account_id=q.account_id
            AND p.generation=s.generation AND p.kind='series' AND p.remote_id=e.series_id
          LEFT JOIN reader_positions r ON r.account_id=q.account_id AND r.book_id=q.book_id''',
          variables: [
            Variable(accountId),
            Variable(jsonEncode(ids.toList(growable: false))),
          ],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('book_id'): _Details(
          known: row.readNullable<String>('title') != null,
          title: row.readNullable<String>('title'),
          seriesId: row.readNullable<String>('series_id'),
          seriesTitle: row.readNullable<String>('series_title'),
          libraryId: row.readNullable<String>('library_id'),
          number: row.readNullable<double>('number') ?? 0,
          pageCount: row.readNullable<int>('page_count') ?? 0,
          modified: row.readNullable<int>('modified') ?? 0,
          available:
              (row.readNullable<bool>('available') ?? true) &&
              !(row.readNullable<bool>('deleted') ?? false),
          mediaType: row.readNullable<String>('media_type') ?? '',
          state:
              ReadingStatus.values
                  .where((v) => v.name == row.read<String>('reading_state'))
                  .firstOrNull ??
              ReadingStatus.unread,
          positionPage: row.readNullable<int>('position_page'),
          positionFraction: row.readNullable<double>('position_fraction'),
          positionTotal: row.readNullable<double>('position_total'),
        ),
    };
  }

  static HistoryEntry _withDetails(HistoryEntry entry, _Details? details) {
    if (details == null) return entry;
    final described = details.known
        ? entry.copyWith(
            title: details.title,
            seriesId: details.seriesId,
            seriesTitle: details.seriesTitle,
            libraryId: details.libraryId,
            number: details.number,
            pageCount: details.pageCount,
            mediaType: details.mediaType,
            modified: details.modified,
            available: details.available,
          )
        : entry;
    return _withLocalState(described, details);
  }

  static HistoryEntry _withCatalogue(HistoryEntry entry, _Details? details) =>
      details == null || !details.known
      ? entry
      : entry.copyWith(
          seriesTitle: details.seriesTitle ?? entry.seriesTitle,
          modified: details.modified,
          available: details.available,
        );

  static HistoryEntry _withLocalState(HistoryEntry entry, _Details details) {
    // A device open without any saved state is at least started.
    final state =
        details.state == ReadingStatus.unread &&
            details.positionPage == null &&
            details.positionTotal == null
        ? entry.status
        : details.state;
    final count = entry.pageCount;
    final ratio = state == ReadingStatus.completed
        ? 1.0
        : details.positionTotal ??
              (details.positionPage != null && count > 0 && !entry.isEbook
                  ? ((details.positionPage! + (details.positionFraction ?? 0)) /
                            count)
                        .clamp(0.0, 1.0)
                  : entry.ratio);
    return entry.copyWith(status: state, ratio: () => ratio);
  }

  void close() {
    _closed = true;
    _token?.cancel();
  }
}

final class _Details {
  const _Details({
    required this.known,
    this.title,
    this.seriesId,
    this.seriesTitle,
    this.libraryId,
    this.number = 0,
    this.pageCount = 0,
    this.modified = 0,
    this.available = true,
    this.mediaType = '',
    this.state = ReadingStatus.unread,
    this.positionPage,
    this.positionFraction,
    this.positionTotal,
  });

  /// The book is in the published catalogue snapshot.
  final bool known;
  final String? title, seriesId, seriesTitle, libraryId;
  final double number;
  final int pageCount, modified;
  final bool available;
  final String mediaType;
  final ReadingStatus state;
  final int? positionPage;
  final double? positionFraction, positionTotal;
}
