import 'catalogue.dart';
import 'catalogue_filters.dart';

/// Named account-local catalogue query, independent of its loaded page window.
final class SavedCatalogueSearch {
  const SavedCatalogueSearch(this.name, this.query);
  final String name;
  final CatalogueQuery query;

  Map<String, Object?> toJson() => {
    'version': 1,
    'name': name,
    'kind': query.kind.name,
    'library': query.libraryId,
    'series': query.seriesId,
    'groupKind': query.groupKind?.name,
    'group': query.groupId,
    'readingUnits': query.readingUnits,
    'search': query.search,
    'sort': query.sort.name,
    'unavailable': query.showUnavailable,
    'status': query.filters.readingStatus.name,
    'downloaded': query.filters.downloadedOnly,
    'facets': {
      for (final entry in query.filters.values.entries)
        entry.key.name: entry.value,
    },
  };

  factory SavedCatalogueSearch.fromJson(Map<String, dynamic> json) {
    String text(String key, int maximum, {bool empty = true}) {
      final value = json[key];
      if (value is! String ||
          value.length > maximum ||
          (!empty && value.trim().isEmpty)) {
        throw const FormatException('Invalid saved search');
      }
      return value;
    }

    String? id(String key) =>
        json[key] == null ? null : text(key, 512, empty: false);
    if (json['version'] != 1 ||
        json['readingUnits'] is! bool ||
        json['downloaded'] is! bool ||
        json['unavailable'] is! bool ||
        json['facets'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved search');
    }
    final facets = <CatalogueFacet, String>{};
    for (final entry in (json['facets'] as Map<String, dynamic>).entries) {
      if (entry.value is! String || (entry.value as String).length > 512) {
        throw const FormatException('Invalid saved filter');
      }
      facets[CatalogueFacet.values.byName(entry.key)] = entry.value as String;
    }
    final group = id('group');
    final groupKind = json['groupKind'] == null
        ? null
        : CatalogueKind.values.byName(text('groupKind', 32));
    if ((group == null) != (groupKind == null)) {
      throw const FormatException('Invalid saved scope');
    }
    return SavedCatalogueSearch(
      text('name', 80, empty: false),
      CatalogueQuery(
        kind: CatalogueKind.values.byName(text('kind', 32)),
        libraryId: id('library'),
        seriesId: id('series'),
        groupId: group,
        groupKind: groupKind,
        readingUnits: json['readingUnits'] as bool,
        search: text('search', 512),
        sort: CatalogueSort.values.byName(text('sort', 32)),
        showUnavailable: json['unavailable'] as bool,
        filters: MetadataFilters.from(
          facets,
          readingStatus: ReadingStatus.values.byName(text('status', 32)),
          downloadedOnly: json['downloaded'] as bool,
        ),
      ),
    );
  }
}
