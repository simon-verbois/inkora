import 'catalogue.dart';
import 'catalogue_filters.dart';
import 'catalogue_metadata.dart';

/// Where the newest timestamp of a history entry comes from: a reader open on
/// this device, or the book's Komga read progress (any device or client).
enum HistorySource { device, server }

/// One book of the reading history. [at] is the newest known activity (UTC):
/// the local open time or Komga's `readProgress.lastModified`. [ratio] is the
/// newest known position (null when unknown); [status] the effective state.
final class HistoryEntry {
  const HistoryEntry({
    required this.bookId,
    required this.title,
    required this.at,
    required this.source,
    this.seriesId,
    this.seriesTitle,
    this.libraryId,
    this.number = 0,
    this.pageCount = 0,
    this.mediaType = '',
    this.modified = 0,
    this.status = ReadingStatus.inProgress,
    this.ratio,
    this.available = true,
  });

  final String bookId, title;
  final DateTime at;
  final HistorySource source;
  final String? seriesId, seriesTitle, libraryId;
  final double number;
  final int pageCount, modified;
  final String mediaType;
  final ReadingStatus status;
  final double? ratio;
  final bool available;

  bool get isEbook =>
      mediaType == 'application/epub+zip' || mediaType == 'application/pdf';

  /// Catalogue item used to load the cover and to open the reader.
  CatalogueItem get item => CatalogueItem(
    kind: CatalogueKind.book,
    id: bookId,
    title: title,
    seriesId: seriesId,
    libraryId: libraryId,
    number: number,
    pageCount: pageCount,
    modified: modified,
    available: available,
    readingStatus: status,
    metadata: CatalogueMetadata(mediaType: mediaType),
  );

  HistoryEntry copyWith({
    String? title,
    DateTime? at,
    HistorySource? source,
    String? seriesId,
    String? seriesTitle,
    String? libraryId,
    double? number,
    int? pageCount,
    String? mediaType,
    int? modified,
    ReadingStatus? status,
    double? Function()? ratio,
    bool? available,
  }) => HistoryEntry(
    bookId: bookId,
    title: title ?? this.title,
    at: at ?? this.at,
    source: source ?? this.source,
    seriesId: seriesId ?? this.seriesId,
    seriesTitle: seriesTitle ?? this.seriesTitle,
    libraryId: libraryId ?? this.libraryId,
    number: number ?? this.number,
    pageCount: pageCount ?? this.pageCount,
    mediaType: mediaType ?? this.mediaType,
    modified: modified ?? this.modified,
    status: status ?? this.status,
    ratio: ratio == null ? this.ratio : ratio(),
    available: available ?? this.available,
  );

  /// Lean cached form of a server entry (no descriptive metadata).
  Map<String, Object?> toJson() => {
    'id': bookId,
    'title': title,
    'at': at.toUtc().toIso8601String(),
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    'libraryId': libraryId,
    'number': number,
    'pageCount': pageCount,
    'mediaType': mediaType,
    'modified': modified,
    'status': status.name,
    'ratio': ratio,
    'available': available,
  };

  static HistoryEntry fromJson(Map<String, dynamic> json) => HistoryEntry(
    bookId: json['id'] as String,
    title: json['title'] as String,
    at: DateTime.parse(json['at'] as String).toUtc(),
    source: HistorySource.server,
    seriesId: json['seriesId'] as String?,
    seriesTitle: json['seriesTitle'] as String?,
    libraryId: json['libraryId'] as String?,
    number: (json['number'] as num?)?.toDouble() ?? 0,
    pageCount: json['pageCount'] as int? ?? 0,
    mediaType: json['mediaType'] as String? ?? '',
    modified: json['modified'] as int? ?? 0,
    status:
        ReadingStatus.values
            .where((value) => value.name == json['status'])
            .firstOrNull ??
        ReadingStatus.inProgress,
    ratio: (json['ratio'] as num?)?.toDouble(),
    available: json['available'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.bookId == bookId &&
      other.title == title &&
      other.at == at &&
      other.source == source &&
      other.seriesId == seriesId &&
      other.seriesTitle == seriesTitle &&
      other.libraryId == libraryId &&
      other.number == number &&
      other.pageCount == pageCount &&
      other.mediaType == mediaType &&
      other.modified == modified &&
      other.status == status &&
      other.ratio == ratio &&
      other.available == available;
  @override
  int get hashCode => Object.hash(
    bookId,
    title,
    at,
    source,
    seriesId,
    seriesTitle,
    libraryId,
    number,
    pageCount,
    mediaType,
    modified,
    status,
    ratio,
    available,
  );
}

/// One entry per book, newest activity first. When a book has both a device
/// open and server progress, the newest timestamp wins and decides the
/// [HistoryEntry.source]; descriptive fields come from the server entry
/// (device opens only know the title). Ties keep the server entry.
List<HistoryEntry> mergeReadingHistory(
  Iterable<HistoryEntry> device,
  Iterable<HistoryEntry> server,
) {
  final merged = <String, HistoryEntry>{};
  for (final entry in server) {
    final known = merged[entry.bookId];
    if (known == null || entry.at.isAfter(known.at)) {
      merged[entry.bookId] = entry;
    }
  }
  for (final entry in device) {
    final known = merged[entry.bookId];
    if (known == null) {
      merged[entry.bookId] = entry;
    } else if (entry.at.isAfter(known.at)) {
      merged[entry.bookId] = known.source == HistorySource.server
          ? known.copyWith(at: entry.at, source: HistorySource.device)
          : entry;
    }
  }
  return merged.values.toList()..sort(compareHistory);
}

/// Newest first; equal times in book id order (stable across refreshes).
int compareHistory(HistoryEntry a, HistoryEntry b) {
  final order = b.at.compareTo(a.at);
  return order != 0 ? order : a.bookId.compareTo(b.bookId);
}

/// Day groups of the history screen.
enum HistoryPeriod { today, yesterday, thisWeek, earlier }

/// Group of [at] relative to [now], in [now]'s time zone (local calendar
/// days). This week covers the five days before yesterday, so the three
/// recent groups span the last seven calendar days.
HistoryPeriod historyPeriod(DateTime at, DateTime now) {
  final local = at.isUtc && !now.isUtc ? at.toLocal() : at;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  // Rounded hours tolerate 23/25-hour days around daylight-saving changes.
  final days = (today.difference(day).inHours / 24).round();
  if (days <= 0) return HistoryPeriod.today;
  if (days == 1) return HistoryPeriod.yesterday;
  if (days < 7) return HistoryPeriod.thisWeek;
  return HistoryPeriod.earlier;
}

String historyPeriodLabel(HistoryPeriod period) => switch (period) {
  HistoryPeriod.today => 'Today',
  HistoryPeriod.yesterday => 'Yesterday',
  HistoryPeriod.thisWeek => 'This week',
  HistoryPeriod.earlier => 'Earlier',
};
