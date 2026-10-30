import 'dart:async';

import 'package:inkora/core/errors/failure_kind.dart';
import 'package:inkora/core/network/komga/api_failure.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';

CatalogueItem entry(
  String id, {
  CatalogueKind kind = CatalogueKind.book,
  String? title,
  String? libraryId = 'library-a',
  String? seriesId = 'series-a',
  double number = 0,
  int modified = 0,
  bool deleted = false,
  bool available = true,
  List<String> members = const [],
  bool ordered = true,
}) => CatalogueItem(
  id: id,
  kind: kind,
  title: title ?? id,
  libraryId: kind == CatalogueKind.book || kind == CatalogueKind.series
      ? libraryId
      : null,
  seriesId: kind == CatalogueKind.book ? seriesId : null,
  number: number,
  modified: modified,
  deleted: deleted,
  available: available,
  members: members,
  ordered: ordered,
  itemCount: members.length,
  pageCount: kind == CatalogueKind.book ? 10 : 0,
);

class FakeCatalogueRemote implements CatalogueRemote {
  final items = <CatalogueKind, List<CatalogueItem>>{};
  int pageSize = 2;
  int calls = 0;
  bool cancelled = false;
  CatalogueKind? failKind;
  int failPage = 0;
  Completer<void>? hold;
  void Function(CatalogueKind kind, int page)? onFetch;
  @override
  Future<RemoteCataloguePage> fetch(CatalogueKind kind, int page) async {
    calls++;
    onFetch?.call(kind, page);
    if (hold != null) await hold!.future;
    if (kind == failKind && page == failPage) {
      throw const ApiFailure(
        FailureKind.offlineUnavailable,
        'Network unavailable.',
      );
    }
    final source = items[kind] ?? [];
    final offset = page * pageSize;
    final content = source.skip(offset).take(pageSize).toList();
    return RemoteCataloguePage(
      items: content,
      number: page,
      totalElements: source.length,
      totalPages: (source.length + pageSize - 1) ~/ pageSize,
      last: offset + content.length >= source.length,
    );
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

CatalogueItem series(
  String id, {
  String status = '',
  int count = 0,
  String library = 'a',
  List<String> genres = const [],
  bool available = true,
}) => CatalogueItem(
  kind: CatalogueKind.series,
  id: id,
  title: id,
  libraryId: library,
  itemCount: count,
  available: available,
  metadata: CatalogueMetadata(status: status, genres: genres),
);
