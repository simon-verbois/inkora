import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/catalogue_metadata.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';

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

ResumeEntry reading(String seriesId, {List<String> genres = const []}) =>
    ResumeEntry(
      item: CatalogueItem(
        kind: CatalogueKind.book,
        id: 'book-$seriesId',
        title: seriesId,
        seriesId: seriesId,
        metadata: CatalogueMetadata(genres: genres),
      ),
      pageIndex: 1,
      pageCount: 10,
      fraction: 0,
    );
