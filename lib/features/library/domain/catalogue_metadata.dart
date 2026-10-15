/// Descriptive Komga fields, independent from reading settings and permissions.
final class CatalogueMetadata {
  const CatalogueMetadata({
    this.mediaType = '',
    this.status = '',
    this.publisher = '',
    this.language = '',
    this.readingDirection = '',
    this.ageRating,
    this.releaseDate = '',
    this.isbn = '',
    this.genres = const [],
    this.tags = const [],
    this.authors = const [],
    this.links = const [],
  });

  final String mediaType;
  final String status, publisher, language, readingDirection, releaseDate, isbn;
  final int? ageRating;
  final List<String> genres, tags;
  final List<CatalogueAuthor> authors;
  final List<CatalogueLink> links;

  factory CatalogueMetadata.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value == null) return '';
      if (value is! String) {
        throw const FormatException('Invalid metadata text');
      }
      return value.trim();
    }

    List<T> list<T>(String key, T Function(Object?) parse) {
      final value = json[key];
      if (value == null) return const [];
      if (value is! List) throw const FormatException('Invalid metadata list');
      return List.unmodifiable(value.map(parse));
    }

    List<String> labels(String key) => List.unmodifiable(
      list(key, (value) {
        if (value is! String) {
          throw const FormatException('Invalid metadata label');
        }
        return value.trim();
      }).where((value) => value.isNotEmpty).toSet(),
    );

    Map<String, dynamic> object(Object? value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid metadata object');
      }
      return value;
    }

    String field(Map<String, dynamic> value, String key) {
      final result = value[key];
      if (result is! String) {
        throw const FormatException('Invalid metadata field');
      }
      return result.trim();
    }

    final rating = json['ageRating'];
    if (rating != null && rating is! int) {
      throw const FormatException('Invalid age rating');
    }
    return CatalogueMetadata(
      mediaType: text('mediaType'),
      status: text('status'),
      publisher: text('publisher'),
      language: text('language'),
      readingDirection: text('readingDirection'),
      ageRating: rating as int?,
      releaseDate: text('releaseDate'),
      isbn: text('isbn'),
      genres: labels('genres'),
      tags: labels('tags'),
      authors: list('authors', (value) {
        final author = object(value);
        return CatalogueAuthor(field(author, 'name'), field(author, 'role'));
      }).where((author) => author.name.isNotEmpty).toList(growable: false),
      links: list('links', (value) {
        final link = object(value);
        return CatalogueLink(field(link, 'label'), field(link, 'url'));
      }).where((link) => link.url.isNotEmpty).toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'mediaType': mediaType,
    'status': status,
    'publisher': publisher,
    'language': language,
    'readingDirection': readingDirection,
    'ageRating': ageRating,
    'releaseDate': releaseDate,
    'isbn': isbn,
    'genres': genres,
    'tags': tags,
    'authors': [
      for (final author in authors) {'name': author.name, 'role': author.role},
    ],
    'links': [
      for (final link in links) {'label': link.label, 'url': link.url},
    ],
  };

  /// Books retain their own credits/tags/links; series-only fields fill gaps.
  CatalogueMetadata withSeries(CatalogueMetadata? series) => series == null
      ? this
      : CatalogueMetadata(
          mediaType: mediaType,
          status: status.isEmpty ? series.status : status,
          publisher: publisher.isEmpty ? series.publisher : publisher,
          language: language.isEmpty ? series.language : language,
          readingDirection: readingDirection.isEmpty
              ? series.readingDirection
              : readingDirection,
          ageRating: ageRating ?? series.ageRating,
          releaseDate: releaseDate,
          isbn: isbn,
          genres: genres.isEmpty ? series.genres : genres,
          tags: tags,
          authors: authors,
          links: links,
        );
}

final class CatalogueAuthor {
  const CatalogueAuthor(this.name, this.role);
  final String name, role;
}

final class CatalogueLink {
  const CatalogueLink(this.label, this.url);
  final String label, url;
}
