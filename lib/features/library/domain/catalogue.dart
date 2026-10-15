import 'catalogue_metadata.dart';

enum CatalogueKind { library, series, book, collection, readlist }

enum CatalogueSort { title, titleDescending, recentlyUpdated, sequence }

/// Metadata only. Credentials and local reader/outbox state never enter snapshots.
final class CatalogueItem {
  const CatalogueItem({
    required this.kind,
    required this.id,
    required this.title,
    this.sortTitle = '',
    this.summary = '',
    this.metadata = const CatalogueMetadata(),
    this.searchText = '',
    this.libraryId,
    this.seriesId,
    this.number = 0,
    this.itemCount = 0,
    this.pageCount = 0,
    this.modified = 0,
    this.deleted = false,
    this.available = true,
    this.ordered = false,
    this.members = const [],
    this.membershipRemoved = false,
  });
  final CatalogueKind kind;
  final String id;
  final String title;
  final String sortTitle;
  final String summary;
  final CatalogueMetadata metadata;
  final String searchText;
  final String? libraryId;
  final String? seriesId;
  final double number;
  final int itemCount;
  final int pageCount;
  final int modified;
  final bool deleted;
  final bool available;
  final bool ordered;
  final List<String> members;
  final bool membershipRemoved;
  bool get isEbook =>
      kind == CatalogueKind.book &&
      (metadata.mediaType == 'application/epub+zip' ||
          metadata.mediaType == 'application/pdf');

  /// Kind namespaces prevent book and series IDs from colliding in mixed shelves.
  String get identity => '${kind.name}:$id';

  bool get canOpen => available && !deleted && !membershipRemoved;
}

final class CatalogueQuery {
  const CatalogueQuery({
    required this.kind,
    this.libraryId,
    this.seriesId,
    this.groupKind,
    this.groupId,
    this.readingUnits = false,
    this.search = '',
    this.sort = CatalogueSort.title,
    this.showUnavailable = true,
    this.page = 0,
    this.pageSize = 30,
  });
  final CatalogueKind kind;
  final String? libraryId;
  final String? seriesId;
  final CatalogueKind? groupKind;
  final String? groupId;

  /// Project ebook books alongside comic series without changing server identity.
  final bool readingUnits;
  final String search;
  final CatalogueSort sort;
  final bool showUnavailable;
  final int page;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is CatalogueQuery &&
      kind == other.kind &&
      readingUnits == other.readingUnits &&
      libraryId == other.libraryId &&
      seriesId == other.seriesId &&
      groupKind == other.groupKind &&
      groupId == other.groupId &&
      search == other.search &&
      sort == other.sort &&
      showUnavailable == other.showUnavailable &&
      page == other.page &&
      pageSize == other.pageSize;
  @override
  int get hashCode => Object.hash(
    kind,
    readingUnits,
    libraryId,
    seriesId,
    groupKind,
    groupId,
    search,
    sort,
    showUnavailable,
    page,
    pageSize,
  );
}

final class LocalCataloguePage {
  const LocalCataloguePage(this.items, this.total, this.lastUpdated);
  final List<CatalogueItem> items;
  final int total;
  final DateTime? lastUpdated;
}

final class RemoteCataloguePage {
  const RemoteCataloguePage({
    required this.items,
    required this.number,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });
  final List<CatalogueItem> items;
  final int number;
  final int totalElements;
  final int totalPages;
  final bool last;
}

abstract interface class CatalogueRemote {
  Future<RemoteCataloguePage> fetch(CatalogueKind kind, int page);
  void cancel();
}

final class CatalogueRefreshState {
  const CatalogueRefreshState({this.busy = false, this.message});
  final bool busy;
  final String? message;
}
