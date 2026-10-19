import 'catalogue_metadata.dart';

/// Values are server metadata and are never translated by the client.
enum CatalogueFacet {
  genres('Genres', true),
  tags('Tags', true),
  authors('Authors', true),
  publisher('Publisher'),
  language('Language'),
  status('Status'),
  ageRating('Age rating'),
  mediaType('Format');

  const CatalogueFacet(this.label, [this.multiple = false]);
  final String label;
  final bool multiple;

  Iterable<String> entries(CatalogueMetadata metadata) => switch (this) {
    genres => metadata.genres,
    tags => metadata.tags,
    authors => metadata.authors.map((author) => author.name),
    publisher => [metadata.publisher],
    language => [metadata.language],
    status => [metadata.status],
    ageRating => [if (metadata.ageRating != null) '${metadata.ageRating}'],
    mediaType => [metadata.mediaType],
  };
}

enum ReadingStatus { any, unread, inProgress, completed }

/// One exact value per dimension; different dimensions intersect.
final class MetadataFilters {
  const MetadataFilters({
    this.readingStatus = ReadingStatus.any,
    this.downloadedOnly = false,
  }) : values = const {};
  MetadataFilters.from(
    Map<CatalogueFacet, String> values, {
    this.readingStatus = ReadingStatus.any,
    this.downloadedOnly = false,
  }) : values = Map.unmodifiable(values);
  final Map<CatalogueFacet, String> values;
  final ReadingStatus readingStatus;
  final bool downloadedOnly;
  bool get isEmpty =>
      values.isEmpty && readingStatus == ReadingStatus.any && !downloadedOnly;
  bool matches(CatalogueMetadata metadata) => values.entries.every(
    (entry) => entry.key.entries(metadata).contains(entry.value),
  );
  @override
  bool operator ==(Object other) =>
      other is MetadataFilters &&
      readingStatus == other.readingStatus &&
      downloadedOnly == other.downloadedOnly &&
      CatalogueFacet.values.every(
        (facet) => values[facet] == other.values[facet],
      );
  @override
  int get hashCode => Object.hashAll([
    readingStatus,
    downloadedOnly,
    for (final facet in CatalogueFacet.values) values[facet],
  ]);
}

typedef CatalogueFacets = Map<CatalogueFacet, List<String>>;
