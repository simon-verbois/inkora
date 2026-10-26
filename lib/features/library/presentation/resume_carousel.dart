import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/resume_entry.dart';
import 'catalogue_card.dart';
import '../domain/catalogue.dart';

/// Shelf card of a saved position: the book itself for ebooks, its series
/// for comics (series title plus the shared progress label, never a file
/// name). Null for comic books without a series.
CatalogueItem? resumeShelfItem(ResumeEntry entry) {
  if (entry.isEbook) return entry.item;
  final id = entry.item.seriesId;
  if (id == null || id.isEmpty) return null;
  return CatalogueItem(
    kind: CatalogueKind.series,
    id: id,
    title: entry.seriesTitle,
    libraryId: entry.item.libraryId,
    modified: entry.item.modified,
    available: entry.item.available,
    deleted: entry.item.deleted,
    membershipRemoved: entry.item.membershipRemoved,
  );
}

/// One entry per reading unit (series or ebook), first entry wins.
Map<String, ResumeEntry> _byReadingUnit(List<ResumeEntry> entries) {
  final reading = <String, ResumeEntry>{};
  for (final entry in entries) {
    if (resumeShelfItem(entry) != null) {
      reading.putIfAbsent(entry.readingIdentity, () => entry);
    }
  }
  return reading;
}

/// Cover-led saved positions, with the next book peeking into the viewport.
/// Every card opens its saved book directly; Back returns Home.
class ResumeCarousel extends StatelessWidget {
  const ResumeCarousel({
    super.key,
    required this.entries,
    this.onViewAll,
    this.columns,
    this.onMarkReading,
  });
  final List<ResumeEntry> entries;
  final int? columns;
  final void Function(ResumeEntry entry, bool read)? onMarkReading;

  /// Destination of the end card shown when more than
  /// [CatalogueShelf.maxItems] positions exist (reading history on Home).
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final reading = _byReadingUnit(entries);
    return CatalogueShelf(
      key: const PageStorageKey('resume-carousel'),
      onViewAll: onViewAll,
      columns: columns,
      viewAllLabel: 'Reading history',
      items: [for (final entry in reading.values) resumeShelfItem(entry)!],
      resumeEntries: reading,
      onMarkReading: onMarkReading == null
          ? null
          : (item, read) {
              final entry = reading[item.identity];
              if (entry != null && entry.item.canOpen && !entry.onDeck) {
                onMarkReading!(entry, read);
              }
            },
      onOpen: (item) {
        final book = reading[item.identity]?.item;
        if (book == null || !book.canOpen) return;
        context.pushNamed('reader', pathParameters: {'id': book.id});
      },
    );
  }
}

/// Komga On Deck: the next unread volume of series the user is reading.
/// Comic cards show the series and open its details (the Home rule for
/// shelves other than Continue reading); their menu can open the volume
/// directly. Ebook cards open the book.
class UpNextShelf extends StatelessWidget {
  const UpNextShelf({super.key, required this.entries, this.columns});
  final List<ResumeEntry> entries;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final reading = _byReadingUnit(entries);
    return CatalogueShelf(
      key: const PageStorageKey('up-next-shelf'),
      columns: columns,
      items: [for (final entry in reading.values) resumeShelfItem(entry)!],
      resumeEntries: reading,
      resumeOpensBook: false,
    );
  }
}
