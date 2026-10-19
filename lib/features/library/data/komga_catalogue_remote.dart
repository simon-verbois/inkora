import 'package:dio/dio.dart';

import '../../../core/network/komga/komga_client.dart';
import '../../../core/network/komga/komga_models.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_filters.dart';
import '../domain/catalogue_metadata.dart';

CatalogueItem parseCatalogueItem(Object? value, CatalogueKind kind) {
  final json = jsonObject(value);
  final id = requiredString(json, 'id');
  final name = requiredString(json, 'name');
  final metadata = json['metadata'] == null
      ? <String, dynamic>{}
      : jsonObject(json['metadata']);
  String text(Map<String, dynamic> source, String key, [String fallback = '']) {
    final value = source[key];
    if (value == null) return fallback;
    if (value is! String) throw const FormatException('Invalid metadata text');
    return value.isEmpty ? fallback : value;
  }

  final aggregated =
      kind == CatalogueKind.series && json['booksMetadata'] != null
      ? jsonObject(json['booksMetadata'])
      : <String, dynamic>{};
  final descriptive = CatalogueMetadata.fromJson({
    ...metadata,
    if (kind == CatalogueKind.book)
      'mediaType': jsonObject(json['media'])['mediaType'] ?? '',
    if (kind == CatalogueKind.series) ...{
      'authors': aggregated['authors'] ?? const <Object?>[],
      'tags': [
        ...CatalogueMetadata.fromJson(metadata).tags,
        ...CatalogueMetadata.fromJson(aggregated).tags,
      ],
    },
  });
  final title = text(metadata, 'title', name);
  final sortTitle = text(metadata, 'titleSort', title).toLowerCase();
  final summary = text(
    metadata,
    'summary',
    text(aggregated, 'summary', text(json, 'summary')),
  );
  final libraryId = kind == CatalogueKind.series || kind == CatalogueKind.book
      ? requiredString(json, 'libraryId')
      : null;
  final seriesId = kind == CatalogueKind.book
      ? requiredString(json, 'seriesId')
      : null;
  final deleted = libraryId != null ? requiredBool(json, 'deleted') : false;
  final ordered =
      kind == CatalogueKind.collection || kind == CatalogueKind.readlist
      ? requiredBool(json, 'ordered')
      : false;
  final memberKey = kind == CatalogueKind.collection
      ? 'seriesIds'
      : kind == CatalogueKind.readlist
      ? 'bookIds'
      : null;
  final members = <String>[];
  if (memberKey != null) {
    final ids = json[memberKey];
    if (ids is! List || ids.any((v) => v is! String || v.isEmpty)) {
      throw const FormatException('Invalid membership');
    }
    members.addAll(ids.cast<String>());
    if (members.toSet().length != members.length) {
      throw const FormatException('Duplicate membership');
    }
  }
  final date = text(json, 'lastModified', text(json, 'lastModifiedDate'));
  final modified = date.isEmpty
      ? 0
      : (DateTime.tryParse(date)?.toUtc().millisecondsSinceEpoch ??
            (throw const FormatException('Invalid timestamp')));
  final number = metadata['numberSort'];
  if (number != null && number is! num) {
    throw const FormatException('Invalid book number');
  }
  final searchable = <String>[
    title,
    name,
    ...descriptive.tags,
    ...descriptive.genres,
    ...descriptive.authors.map((author) => author.name),
    summary,
    text(metadata, 'publisher'),
  ];
  final alternateTitles = metadata['alternateTitles'];
  if (alternateTitles is List) {
    for (final value in alternateTitles) {
      if (value is Map<String, dynamic> && value['title'] is String) {
        searchable.add(value['title'] as String);
      }
    }
  }
  return CatalogueItem(
    kind: kind,
    id: id,
    title: title,
    readingStatus: json['readProgress'] is Map
        ? ((json['readProgress'] as Map)['completed'] == true
              ? ReadingStatus.completed
              : ReadingStatus.inProgress)
        : ReadingStatus.unread,
    sortTitle: sortTitle,
    summary: summary,
    metadata: descriptive,
    searchText: searchable.join(' ').toLowerCase(),
    libraryId: libraryId,
    seriesId: seriesId,
    number: (number as num?)?.toDouble() ?? 0,
    modified: modified,
    deleted: deleted,
    available: kind == CatalogueKind.library
        ? !requiredBool(json, 'unavailable')
        : !deleted,
    ordered: ordered,
    members: List.unmodifiable(members),
    itemCount: kind == CatalogueKind.series
        ? requiredInt(json, 'booksCount')
        : members.length,
    pageCount: kind == CatalogueKind.book
        ? requiredInt(jsonObject(json['media']), 'pagesCount')
        : 0,
  );
}

/// Top-level parser factory: the closure captures only [kind], so it can be
/// sent to the worker isolate that parses refresh pages.
CatalogueItem Function(Object?) catalogueItemParser(CatalogueKind kind) =>
    (json) => parseCatalogueItem(json, kind);

final class KomgaCatalogueRemote implements CatalogueRemote {
  KomgaCatalogueRemote(this.client);
  final KomgaClient client;
  final _cancel = CancelToken();
  @override
  Future<RemoteCataloguePage> fetch(CatalogueKind kind, int page) async {
    if (kind == CatalogueKind.library) {
      final items = await client.catalogueLibraries(
        (json) => parseCatalogueItem(json, kind),
        cancelToken: _cancel,
      );
      return RemoteCataloguePage(
        items: items,
        number: 0,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        last: true,
      );
    }
    final result = await client.cataloguePage(
      kind.name,
      catalogueItemParser(kind),
      page: page,
      cancelToken: _cancel,
      parseInBackground: true,
    );
    return RemoteCataloguePage(
      items: result.items,
      number: result.number,
      totalElements: result.totalElements,
      totalPages: result.totalPages,
      last: result.last,
    );
  }

  @override
  void cancel() => _cancel.cancel();
}
