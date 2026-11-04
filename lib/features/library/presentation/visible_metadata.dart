import '../../settings/domain/metadata_visibility.dart';
import '../domain/catalogue_metadata.dart';

/// A display-only projection; raw records still feed search, sync and readers.
CatalogueMetadata visibleMetadata(
  CatalogueMetadata metadata,
  MetadataVisibility visibility,
) => CatalogueMetadata(
  mediaType: visibility.shows(MetadataField.format) ? metadata.mediaType : '',
  status: visibility.shows(MetadataField.status) ? metadata.status : '',
  publisher: visibility.shows(MetadataField.publisher)
      ? metadata.publisher
      : '',
  language: visibility.shows(MetadataField.language) ? metadata.language : '',
  readingDirection: visibility.shows(MetadataField.readingDirection)
      ? metadata.readingDirection
      : '',
  ageRating: visibility.shows(MetadataField.ageRating)
      ? metadata.ageRating
      : null,
  releaseDate: visibility.shows(MetadataField.releaseDate)
      ? metadata.releaseDate
      : '',
  isbn: visibility.shows(MetadataField.isbn) ? metadata.isbn : '',
  genres: visibility.shows(MetadataField.genres) ? metadata.genres : const [],
  tags: visibility.shows(MetadataField.tags) ? metadata.tags : const [],
  authors: metadata.authors
      .where((author) => visibility.showsCredit(author.role))
      .toList(growable: false),
  links: visibility.shows(MetadataField.links) ? metadata.links : const [],
);
