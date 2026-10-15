import '../../settings/domain/ui_preferences.dart';
import '../../../app/l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/resume_entry.dart';
import 'catalogue_card.dart';
import '../domain/catalogue.dart';

/// Cover-led saved positions, with the next book peeking into the viewport.
class ResumeCarousel extends StatelessWidget {
  const ResumeCarousel({
    super.key,
    required this.entries,
    this.onViewAll,
    this.density = CatalogueDensity.comfortable,
  });
  final List<ResumeEntry> entries;
  final CatalogueDensity density;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final reading = <String, ResumeEntry>{};
    for (final entry in entries) {
      final id = entry.item.seriesId;
      if (entry.isEbook || (id != null && id.isNotEmpty)) {
        reading.putIfAbsent(entry.readingIdentity, () => entry);
      }
    }
    final items = [
      for (final entry in reading.values)
        if (entry.isEbook)
          entry.item
        else
          CatalogueItem(
            kind: CatalogueKind.series,
            id: entry.item.seriesId!,
            title: entry.seriesTitle,
            libraryId: entry.item.libraryId,
            modified: entry.item.modified,
            available: entry.item.available,
            deleted: entry.item.deleted,
            membershipRemoved: entry.item.membershipRemoved,
          ),
    ];
    return CatalogueShelf(
      key: const PageStorageKey('resume-carousel'),
      onViewAll: onViewAll,
      density: density,
      viewAllLabel: context.tr("Continue reading"),
      items: items,
      resumeEntries: {
        for (final entry in reading.entries) entry.key: entry.value,
      },
      onOpen: (item) {
        final book = reading[item.identity]?.item;
        if (book == null || !book.canOpen) return;
        context.pushNamed('reader', pathParameters: {'id': book.id});
      },
    );
  }
}
