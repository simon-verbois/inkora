import 'package:flutter_test/flutter_test.dart';
import 'package:inkora/features/library/domain/catalogue.dart';
import 'package:inkora/features/library/domain/discovery.dart';
import 'package:inkora/features/library/domain/resume_entry.dart';

import '../../support/discovery_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 12);
  DiscoveryMemory memory(
    DiscoveryTheme theme, {
    List<String> ids = const [],
    List<String> recent = const [],
  }) => DiscoveryMemory(
    day: discoveryDay(now),
    cycle: 0,
    theme: theme,
    ids: ids,
    recentIds: recent,
  );
  (DiscoveryPage, DiscoveryMemory) select(
    List<CatalogueItem> candidates, {
    DiscoveryMemory? previous,
    List<ResumeEntry> resume = const [],
    DateTime? date,
  }) => selectDiscovery(
    candidates: candidates,
    resume: resume,
    accountId: 'account',
    now: date ?? now,
    previous: previous,
  );

  test(
    'themes use actual genre, publication status and known short lengths',
    () {
      final candidates = [
        series('affinity', genres: [' FANTASY '], count: 20),
        series('ended', status: 'ended', count: 30),
        series('short', count: 5),
        series('unknown'),
        series('reading', genres: ['fantasy'], count: 1),
        series('unavailable', count: 1, available: false),
      ];
      final resume = [
        reading('reading', genres: ['Fantasy']),
      ];
      for (final (theme, expected) in [
        (DiscoveryTheme.similar, ['affinity']),
        (DiscoveryTheme.completed, ['ended']),
        (DiscoveryTheme.short, ['short']),
      ]) {
        final (page, _) = select(
          candidates,
          previous: memory(theme, ids: expected),
          resume: resume,
        );
        expect(page.theme, theme);
        expect(page.items.map((item) => item.id), expected);
      }
      final (surprises, _) = select(
        candidates,
        previous: memory(
          DiscoveryTheme.surprise,
          ids: ['affinity', 'ended', 'short', 'unknown'],
        ),
        resume: resume,
      );
      expect(surprises.items.map((item) => item.id).toSet(), {
        'affinity',
        'ended',
        'short',
        'unknown',
      });
    },
  );

  test(
    'navigation and input order preserve stored picks; all resume IDs excluded',
    () {
      final candidates = List.generate(40, (i) => series('series-$i'));
      final resume = List.generate(14, (i) => reading('series-$i'));
      final (page, stored) = select(candidates, resume: resume);
      expect(page.items, hasLength(10));
      expect(
        page.items.every(
          (item) => !resume.any((entry) => entry.item.seriesId == item.id),
        ),
        isTrue,
      );
      final (returned, _) = select(
        candidates.reversed.toList(),
        previous: stored,
        resume: resume,
      );
      expect(returned.items.map((item) => item.identity), stored.ids);
      final newReading = reading(stored.ids.first.substring(7));
      final (updated, _) = select(
        candidates,
        previous: stored,
        resume: [...resume, newReading],
      );
      expect(updated.items, hasLength(9));
      expect(
        updated.items.any((item) => item.id == newReading.item.seriesId),
        isFalse,
      );
      expect(
        updated.items.take(9).map((item) => item.identity),
        stored.ids.skip(1),
      );
    },
  );

  test(
    'new launch days rotate eligible themes, falling back without metadata',
    () {
      final candidates = [
        series('affinity', genres: ['fantasy']),
        series('ended', status: 'ENDED', count: 20),
        series('short', count: 2),
      ];
      var stored = memory(DiscoveryTheme.similar, ids: ['affinity']);
      var launch = now;
      for (final next in [
        DiscoveryTheme.completed,
        DiscoveryTheme.short,
        DiscoveryTheme.surprise,
        DiscoveryTheme.similar,
      ]) {
        launch = launch.add(const Duration(days: 1));
        final (page, updated) = select(
          candidates,
          date: launch,
          previous: stored,
          resume: [
            reading('ongoing', genres: ['fantasy']),
          ],
        );
        expect(page.theme, next);
        expect(updated.cycle, 0);
        stored = updated;
      }
      final (tomorrow, nextDay) = select(
        candidates,
        previous: stored,
        date: launch.add(const Duration(days: 1)),
      );
      expect(tomorrow.theme, DiscoveryTheme.completed);
      expect(nextDay.cycle, 0);
      final (fallback, _) = select(
        [series('unknown')],
        date: now.add(const Duration(days: 1)),
        previous: memory(DiscoveryTheme.similar),
      );
      expect(fallback.theme, DiscoveryTheme.surprise);
      expect(fallback.items.single.id, 'unknown');
    },
  );

  test(
    'fresh picks precede repeats, libraries mix and tiny catalogues still work',
    () {
      final candidates = List.generate(
        40,
        (i) => series('series-$i', library: i < 35 ? 'a' : 'b'),
      );
      final (first, initial) = select(candidates, previous: null);
      expect(first.items.take(2).map((item) => item.libraryId).toSet(), {
        'a',
        'b',
      });
      final (second, updated) = select(
        candidates,
        previous: initial,
        date: now.add(const Duration(days: 1)),
      );
      expect(
        second.items.any((item) => initial.ids.contains(item.identity)),
        isFalse,
      );
      expect(second.items.map((item) => item.identity), isNot(initial.ids));
      expect(updated.ids, hasLength(10));
      final (tiny, _) = select(
        [series('only')],
        date: now.add(const Duration(days: 1)),
        previous: memory(
          DiscoveryTheme.surprise,
          ids: ['only'],
          recent: ['only'],
        ),
      );
      expect(tiny.items.single.id, 'only');
      final (empty, _) = select([series('only')], resume: [reading('only')]);
      expect(empty.items, isEmpty);
    },
  );

  test('history and parsed stored identities are bounded', () {
    final candidates = List.generate(100, (i) => series('series-$i'));
    DiscoveryMemory? previous;
    for (var i = 0; i < 20; i++) {
      final (_, updated) = select(
        candidates,
        previous: previous,
        date: now.add(Duration(days: i)),
      );
      expect(updated.ids.length, lessThanOrEqualTo(10));
      expect(updated.recentIds.length, lessThanOrEqualTo(30));
      previous = updated;
    }
    final parsed = DiscoveryMemory.fromJson({
      ...previous!.toJson(),
      'ids': [null, '', ...List.generate(100, (i) => '$i')],
    });
    expect(parsed!.ids, hasLength(10));
    expect(DiscoveryMemory.fromJson({'day': 'bad'}), isNull);
  });

  test(
    'three themed rows share no picks and remain fixed within their launch day',
    () {
      final candidates = [
        for (var i = 0; i < 30; i++) series('affinity-$i', genres: ['fantasy']),
        for (var i = 0; i < 30; i++)
          series('ended-$i', status: 'ENDED', count: 20),
        for (var i = 0; i < 30; i++) series('short-$i', count: 2),
      ];
      final resume = [
        reading('affinity-0', genres: ['fantasy']),
      ];
      final (pages, stored) = selectDiscoverySections(
        candidates: candidates,
        resume: resume,
        accountId: 'account',
        now: now,
      );
      expect(pages, hasLength(3));
      expect(pages.map((page) => page.theme).toSet(), hasLength(3));
      final ids = pages
          .expand((page) => page.items.map((item) => item.id))
          .toList();
      expect(ids, hasLength(30));
      expect(ids.toSet(), hasLength(30));
      expect(ids, isNot(contains('affinity-0')));
      final (returned, _) = selectDiscoverySections(
        candidates: candidates.reversed,
        resume: resume,
        accountId: 'account',
        now: now,
        previous: stored,
      );
      expect(returned.expand((page) => page.items.map((item) => item.id)), ids);
      // Metadata changes do not swap the theme or fill a vacated card that day.
      final removed = ids.first;
      final (repaired, _) = selectDiscoverySections(
        candidates: candidates.where((item) => item.id != removed),
        resume: resume,
        accountId: 'account',
        now: now,
        previous: stored,
      );
      expect(
        repaired.map((page) => page.theme),
        pages.map((page) => page.theme),
      );
      expect(
        repaired.first.items.map((item) => item.id),
        pages.first.items.skip(1).map((item) => item.id),
      );
      expect(
        repaired.skip(1).expand((page) => page.items.map((item) => item.id)),
        ids.skip(10),
      );
    },
  );

  test(
    'missing metadata gives three honest, differently labelled fallback rows',
    () {
      final candidates = List.generate(40, (i) => series('unknown-$i'));
      final (pages, _) = selectDiscoverySections(
        candidates: candidates,
        resume: [],
        accountId: 'account',
        now: now,
      );
      expect(pages.map((page) => page.label), [
        'Library surprises',
        'From your libraries',
        'More to explore',
      ]);
      final ids = pages
          .expand((page) => page.items.map((item) => item.id))
          .toList();
      expect(ids.toSet(), hasLength(30));
      final (tiny, _) = selectDiscoverySections(
        candidates: [series('only')],
        resume: [],
        accountId: 'account',
        now: now,
      );
      expect(tiny, hasLength(3));
      expect(tiny.expand((page) => page.items).length, 1);
    },
  );
}
