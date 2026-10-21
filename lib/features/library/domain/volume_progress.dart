import 'catalogue.dart';
import 'catalogue_filters.dart';
import 'catalogue_metadata.dart';

/// One volume of a series with the lean snapshot fields used by volume rows,
/// grids and the series progress summary. Server progress comes from the
/// published catalogue snapshot; local progress is layered on top by
/// [resolveVolumeProgress].
final class SeriesVolume {
  const SeriesVolume({
    required this.id,
    required this.seriesId,
    required this.title,
    this.libraryId,
    this.number = 0,
    this.pageCount = 0,
    this.modified = 0,
    this.available = true,
    this.mediaType = '',
    this.serverStatus = ReadingStatus.unread,
    this.serverPage,
    this.serverModified,
  });
  final String id, seriesId, title;
  final String? libraryId;
  final double number;
  final int pageCount, modified;
  final bool available;
  final String mediaType;
  final ReadingStatus serverStatus;
  final int? serverPage;
  final String? serverModified;

  bool get isEbook =>
      mediaType == 'application/epub+zip' || mediaType == 'application/pdf';

  /// Catalogue item used to open the volume and to load its cover.
  CatalogueItem get item => CatalogueItem(
    kind: CatalogueKind.book,
    id: id,
    title: title,
    seriesId: seriesId,
    libraryId: libraryId,
    number: number,
    pageCount: pageCount,
    modified: modified,
    available: available,
    readingStatus: serverStatus,
    readPage: serverPage,
    readModified: serverModified,
    metadata: CatalogueMetadata(mediaType: mediaType),
  );

  @override
  bool operator ==(Object other) =>
      other is SeriesVolume &&
      other.id == id &&
      other.seriesId == seriesId &&
      other.title == title &&
      other.libraryId == libraryId &&
      other.number == number &&
      other.pageCount == pageCount &&
      other.modified == modified &&
      other.available == available &&
      other.mediaType == mediaType &&
      other.serverStatus == serverStatus &&
      other.serverPage == serverPage &&
      other.serverModified == serverModified;
  @override
  int get hashCode => Object.hash(
    id,
    seriesId,
    title,
    libraryId,
    number,
    pageCount,
    modified,
    available,
    mediaType,
    serverStatus,
    serverPage,
    serverModified,
  );
}

/// Local (device) progress of one book: the latest outbox intent, the last
/// observed server baseline and the exact reader position. Only books with
/// at least one of them have an entry.
final class LocalVolumeProgress {
  const LocalVolumeProgress({
    this.operation,
    this.eventPage,
    this.eventPageCount,
    this.eventTotal,
    this.hasBaseline = false,
    this.baselineCompleted = false,
    this.baselinePage,
    this.positionPage,
    this.conflict = false,
  });

  /// Name of the latest pending ProgressOperation, if any.
  final String? operation;
  final int? eventPage, eventPageCount;

  /// Ebook total progression of the latest pending intent.
  final double? eventTotal;
  final bool hasBaseline, baselineCompleted;
  final int? baselinePage, positionPage;

  /// A pending intent of this book waits for the user's conflict choice.
  final bool conflict;

  @override
  bool operator ==(Object other) =>
      other is LocalVolumeProgress &&
      other.operation == operation &&
      other.eventPage == eventPage &&
      other.eventPageCount == eventPageCount &&
      other.eventTotal == eventTotal &&
      other.hasBaseline == hasBaseline &&
      other.baselineCompleted == baselineCompleted &&
      other.baselinePage == baselinePage &&
      other.positionPage == positionPage &&
      other.conflict == conflict;
  @override
  int get hashCode => Object.hash(
    operation,
    eventPage,
    eventPageCount,
    eventTotal,
    hasBaseline,
    baselineCompleted,
    baselinePage,
    positionPage,
    conflict,
  );
}

/// Effective reading state of one volume. [status] is never
/// [ReadingStatus.any]; [ratio] is null when an in-progress position is
/// unknown; [pending] marks a local intent that has not reached Komga yet.
final class VolumeProgress {
  const VolumeProgress({
    required this.status,
    this.pageIndex,
    this.ratio,
    this.pending = false,
    this.conflict = false,
  });
  final ReadingStatus status;
  final int? pageIndex;
  final double? ratio;
  final bool pending, conflict;

  static const unread = VolumeProgress(status: ReadingStatus.unread, ratio: 0);

  bool get read => status == ReadingStatus.completed;
  bool get reading => status == ReadingStatus.inProgress;

  /// Segment fill: read 1, unread 0, unknown in-progress position one half.
  double get fill => switch (status) {
    ReadingStatus.completed => 1,
    ReadingStatus.inProgress => ratio ?? .5,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is VolumeProgress &&
      other.status == status &&
      other.pageIndex == pageIndex &&
      other.ratio == ratio &&
      other.pending == pending &&
      other.conflict == conflict;
  @override
  int get hashCode => Object.hash(status, pageIndex, ratio, pending, conflict);
  @override
  String toString() => 'VolumeProgress($status, $pageIndex, $ratio)';
}

/// Same precedence as `CatalogueStore.readingState`: the latest local intent
/// wins, then the last observed server baseline, then the exact local reader
/// position, then the server reading shelf ([shelf]) and finally the
/// catalogue snapshot. Local writes therefore show immediately (optimistic)
/// and survive until Komga acknowledges them.
VolumeProgress resolveVolumeProgress(
  SeriesVolume volume,
  LocalVolumeProgress? local, {
  ({int pageIndex, double? ratio})? shelf,
}) {
  final count = volume.pageCount;
  double? pageRatio(int page, int pages) =>
      pages < 1 ? null : (page / pages).clamp(0, 1).toDouble();
  final pending = local?.operation != null;
  final conflict = local?.conflict ?? false;
  if (local != null && local.operation != null) {
    final pages = local.eventPageCount ?? count;
    final page = local.eventPage ?? 0;
    final total = local.eventTotal;
    final completed = switch (local.operation) {
      'markUnread' => false,
      'complete' => true,
      _ => total != null ? total >= .99 : pages > 0 && page >= pages - 1,
    };
    if (local.operation == 'markUnread') {
      return VolumeProgress(
        status: ReadingStatus.unread,
        ratio: 0,
        pending: true,
        conflict: conflict,
      );
    }
    return completed
        ? VolumeProgress(
            status: ReadingStatus.completed,
            ratio: 1,
            pending: true,
            conflict: conflict,
          )
        : VolumeProgress(
            status: ReadingStatus.inProgress,
            pageIndex: page,
            ratio: total ?? pageRatio(page, pages),
            pending: true,
            conflict: conflict,
          );
  }
  if (local != null && local.hasBaseline) {
    if (local.baselineCompleted) {
      return VolumeProgress(
        status: ReadingStatus.completed,
        ratio: 1,
        pending: pending,
        conflict: conflict,
      );
    }
    final page = local.baselinePage;
    if (page != null) {
      return VolumeProgress(
        status: ReadingStatus.inProgress,
        pageIndex: page,
        ratio: volume.isEbook ? null : pageRatio(page, count),
        conflict: conflict,
      );
    }
    return VolumeProgress(
      status: ReadingStatus.unread,
      ratio: 0,
      conflict: conflict,
    );
  }
  if (local?.positionPage case final int page) {
    return VolumeProgress(
      status: ReadingStatus.inProgress,
      pageIndex: page,
      ratio: volume.isEbook ? null : pageRatio(page, count),
      conflict: conflict,
    );
  }
  if (shelf != null && volume.serverStatus != ReadingStatus.completed) {
    return VolumeProgress(
      status: ReadingStatus.inProgress,
      pageIndex: shelf.pageIndex,
      ratio: shelf.ratio,
    );
  }
  return switch (volume.serverStatus) {
    ReadingStatus.completed => const VolumeProgress(
      status: ReadingStatus.completed,
      ratio: 1,
    ),
    ReadingStatus.inProgress => VolumeProgress(
      status: ReadingStatus.inProgress,
      pageIndex: volume.serverPage,
      ratio: volume.serverPage == null || volume.isEbook
          ? null
          : pageRatio(volume.serverPage!, count),
    ),
    _ => VolumeProgress.unread,
  };
}

/// Ordered volumes of one series with their effective progress.
final class SeriesProgress {
  SeriesProgress(this.volumes, this.progress)
    : readCount = volumes.where((v) => progress[v.id]?.read ?? false).length;

  /// Volumes in reading (sequence) order.
  final List<SeriesVolume> volumes;
  final Map<String, VolumeProgress> progress;
  final int readCount;

  VolumeProgress of(String id) => progress[id] ?? VolumeProgress.unread;

  bool get started =>
      volumes.any((volume) => of(volume.id).status != ReadingStatus.unread);

  /// The volume to continue: the shelf's in-progress book ([resumeBookId])
  /// when it is not finished, otherwise the first in-progress volume, the
  /// server's next volume ([nextBookId], On Deck) and the first unread
  /// volume. Null when every openable volume is read.
  int? currentIndex({String? resumeBookId, String? nextBookId}) {
    int? candidate(String? id) {
      if (id == null) return null;
      final index = volumes.indexWhere(
        (volume) => volume.id == id && volume.available,
      );
      return index >= 0 && !of(id).read ? index : null;
    }

    final resumed = candidate(resumeBookId);
    if (resumed != null) return resumed;
    final reading = volumes.indexWhere(
      (volume) => volume.available && of(volume.id).reading,
    );
    if (reading >= 0) return reading;
    final next = candidate(nextBookId);
    if (next != null) return next;
    final unread = volumes.indexWhere(
      (volume) => volume.available && !of(volume.id).read,
    );
    return unread < 0 ? null : unread;
  }

  /// Fill (0..1) of at most [maximum] segments; each segment averages the
  /// volumes it covers, so long series stay readable.
  List<double> segments([int maximum = 40]) {
    final count = volumes.length;
    if (count == 0) return const [];
    final segments = count < maximum ? count : maximum;
    return [
      for (var i = 0; i < segments; i++)
        () {
          final start = i * count ~/ segments;
          final end = (i + 1) * count ~/ segments;
          var sum = 0.0;
          for (var v = start; v < end; v++) {
            sum += of(volumes[v].id).fill;
          }
          return end == start ? 0.0 : sum / (end - start);
        }(),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (other is! SeriesProgress ||
        other.volumes.length != volumes.length ||
        other.progress.length != progress.length) {
      return false;
    }
    for (var i = 0; i < volumes.length; i++) {
      if (other.volumes[i] != volumes[i]) return false;
    }
    for (final entry in progress.entries) {
      if (other.progress[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(volumes.length, readCount);
}
