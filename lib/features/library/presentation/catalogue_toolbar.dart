import '../../../app/widgets/ink_filter_bar.dart';
import '../domain/catalogue.dart';

/// Sort choices of catalogue and Downloads filter bars: menu label plus the
/// short label shown on the sort button. [sequence] adds book number order
/// ([groupOrder]: list order of a collection or reading list); [recent] adds
/// Recently updated (not available for downloaded items).
List<InkSortOption<CatalogueSort>> catalogueSortOptions({
  bool recent = true,
  bool sequence = false,
  bool groupOrder = false,
}) => [
  (value: CatalogueSort.title, label: 'Title A–Z', short: 'A–Z'),
  (value: CatalogueSort.titleDescending, label: 'Title Z–A', short: 'Z–A'),
  if (recent)
    (
      value: CatalogueSort.recentlyUpdated,
      label: 'Recently updated',
      short: 'Updated',
    ),
  if (sequence)
    (
      value: CatalogueSort.sequence,
      label: groupOrder ? 'List order' : 'Book number',
      short: '1–9',
    ),
];
