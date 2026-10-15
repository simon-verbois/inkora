import 'dart:convert';

import '../../../core/storage/app_database.dart';
import '../domain/catalogue.dart';
import '../domain/discovery.dart';
import '../domain/resume_entry.dart';
import 'catalogue_store.dart';

/// One account's durable Home suggestions, fixed to the app's launch day.
/// Serial transactions keep publication/progress repairs consistent across rows.
final class DiscoveryRepository {
  DiscoveryRepository(this.catalogue, {DateTime Function()? clock})
    : launchedAt = (clock ?? DateTime.now)();
  final CatalogueStore catalogue;
  final DateTime launchedAt;
  Future<void> _pending = Future.value();

  String get storageKey => 'discovery:${catalogue.accountId}';

  Stream<DiscoveryPage> watch(List<ResumeEntry> resume) =>
      watchSections(resume).map((pages) => pages.first);

  Stream<List<DiscoveryPage>> watchSections(List<ResumeEntry> resume) =>
      catalogue.watchPublications().asyncMap((_) => readSections(resume));

  Future<DiscoveryPage> read(List<ResumeEntry> resume) =>
      readSections(resume).then((pages) => pages.first);

  Future<List<DiscoveryPage>> readSections(List<ResumeEntry> resume) {
    final next = _pending.then((_) async {
      final page = await catalogue.database.transaction(() async {
        final row = await (catalogue.database.select(
          catalogue.database.appPreferences,
        )..where((row) => row.key.equals(storageKey))).getSingleOrNull();
        final visibility = await catalogue.visibility.payload();
        final memories = <DiscoveryMemory>[];
        if (row != null && row.payload.length <= 49152) {
          try {
            final json = jsonDecode(row.payload) as Map<String, dynamic>;
            final stored = json['sections'];
            // Disposable picks renew once when adopting book/series identities.
            final version = json['readingUnitsVersion'];
            final sections = stored is List
                ? stored.take(DiscoveryPage.sectionCount)
                : [json]; // Accept a versioned single-row fixture too.
            for (final section in sections) {
              final memory = section is Map<String, dynamic>
                  ? DiscoveryMemory.fromJson(section)
                  : null;
              if (memory == null ||
                  version != 1 ||
                  json['visibility'] != visibility) {
                break;
              }
              memories.add(memory);
            }
          } catch (_) {
            // A disposable suggestion row must never hide the saved catalogue.
          }
        }
        final now = launchedAt;
        final genres = await catalogue.discoveryReadingGenres({
          for (final entry in resume)
            if (entry.item.seriesId != null) entry.item.seriesId!,
        });
        final retainedIds = memories
            .expand((memory) => memory.ids)
            .toSet()
            .toList();
        final retained =
            memories.length == DiscoveryPage.sectionCount &&
                memories.every((memory) => memory.day == discoveryDay(now))
            ? await catalogue.discoveryCandidates(retainedIds, sample: false)
            : <CatalogueItem>[];
        var selection = selectDiscoverySections(
          candidates: retained,
          readingGenres: genres,
          resume: resume,
          accountId: catalogue.accountId,
          now: now,
          previous: memories,
        );
        if (memories.length != DiscoveryPage.sectionCount ||
            memories.any((memory) => memory.day != discoveryDay(now))) {
          final candidates = await catalogue.discoveryCandidates(retainedIds);
          selection = selectDiscoverySections(
            candidates: candidates,
            readingGenres: genres,
            resume: resume,
            accountId: catalogue.accountId,
            now: now,
            previous: memories,
          );
        }
        final (page, updated) = selection;
        if (memories.isEmpty &&
            page.every((section) => section.items.isEmpty)) {
          return page; // Wait for the first usable catalogue before fixing picks.
        }
        final payload = jsonEncode({
          'readingUnitsVersion': 1,
          'visibility': visibility,
          'sections': updated.map((memory) => memory.toJson()).toList(),
        });
        if (row?.payload != payload) {
          await catalogue.database
              .into(catalogue.database.appPreferences)
              .insertOnConflictUpdate(
                AppPreferencesCompanion.insert(
                  key: storageKey,
                  payload: payload,
                ),
              );
        }
        return page;
      });
      return page;
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
