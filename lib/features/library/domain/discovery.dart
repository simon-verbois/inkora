import 'catalogue.dart';
import 'resume_entry.dart';

enum DiscoveryTheme {
  similar('In the same mood'),
  completed('Completed series'),
  short('Short reads'),
  surprise('Library surprises');

  const DiscoveryTheme(this.label);
  final String label;
}

String discoveryDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final class DiscoveryPage {
  const DiscoveryPage(this.theme, this.items, {this.fallbackLabel});
  static const sectionCount = 3;
  final DiscoveryTheme theme;
  final List<CatalogueItem> items;
  final String? fallbackLabel;
  String get label => fallbackLabel ?? theme.label;
}

/// Local metadata identities only; no credentials, artwork or reading history.
final class DiscoveryMemory {
  const DiscoveryMemory({
    required this.day,
    required this.cycle,
    required this.theme,
    required this.ids,
    required this.recentIds,
  });
  static const maxItems = 10;
  static const maxRecent = 30;
  final String day;
  final int cycle;
  final DiscoveryTheme theme;
  final List<String> ids, recentIds;

  Map<String, Object> toJson() => {
    'day': day,
    'cycle': cycle,
    'theme': theme.name,
    'ids': ids,
    'recentIds': recentIds,
  };

  static DiscoveryMemory? fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final cycle = json['cycle'];
    final theme = json['theme'];
    if (day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        cycle is! int ||
        cycle < 0 ||
        !DiscoveryTheme.values.any((value) => value.name == theme)) {
      return null;
    }
    List<String> ids(Object? value, int limit) => value is List
        ? value
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .take(limit)
              .toList()
        : [];
    return DiscoveryMemory(
      day: day,
      cycle: cycle,
      theme: DiscoveryTheme.values.byName(theme as String),
      ids: ids(json['ids'], maxItems),
      recentIds: ids(json['recentIds'], maxRecent),
    );
  }
}

/// Keep valid stored picks; rotate themes and ordering only for a new launch day.
/// Recent suggestions are a preference, so small libraries still remain usable.
(DiscoveryPage, DiscoveryMemory) selectDiscovery({
  required Iterable<CatalogueItem> candidates,
  required List<ResumeEntry> resume,
  required String accountId,
  required DateTime now,
  Iterable<String> readingGenres = const [],
  Set<String> excludedIds = const {},
  Set<DiscoveryTheme> excludedThemes = const {},
  Iterable<String> recentIds = const [],
  DiscoveryMemory? previous,
}) {
  final day = discoveryDay(now);
  final rotate = previous == null || previous.day != day;
  final cycle = previous?.day == day ? previous!.cycle : 0;
  final seed = '$accountId:$day:$cycle';
  final excluded = {
    for (final entry in resume) entry.readingIdentity,
    ...excludedIds.map(readingIdentity),
  };
  final genres = {
    for (final genre in readingGenres) genre.trim().toLowerCase(),
    for (final entry in resume)
      for (final genre in entry.item.metadata.genres)
        genre.trim().toLowerCase(),
  }..remove('');
  final available = {
    for (final item in candidates)
      if ((item.kind == CatalogueKind.series || item.isEbook) &&
          item.canOpen &&
          !excluded.contains(item.identity))
        item.identity: item,
  };
  bool matches(CatalogueItem item, DiscoveryTheme theme) => switch (theme) {
    DiscoveryTheme.similar => item.metadata.genres.any(
      (genre) => genres.contains(genre.trim().toLowerCase()),
    ),
    DiscoveryTheme.completed =>
      item.kind == CatalogueKind.series &&
          item.metadata.status.trim().toUpperCase() == 'ENDED',
    DiscoveryTheme.short =>
      item.kind == CatalogueKind.series &&
          item.itemCount > 0 &&
          item.itemCount <= 5,
    DiscoveryTheme.surprise => true,
  };
  var theme =
      previous?.theme ??
      DiscoveryTheme.values[_hash(seed) % DiscoveryTheme.values.length];
  if (rotate) {
    final start = previous == null ? theme.index : (theme.index + 1) % 4;
    theme = DiscoveryTheme.surprise;
    for (var i = 0; i < DiscoveryTheme.values.length; i++) {
      final next = DiscoveryTheme.values[(start + i) % 4];
      if (!excludedThemes.contains(next) &&
          available.values.any((item) => matches(item, next))) {
        theme = next;
        break;
      }
    }
  }
  final picks = <CatalogueItem>[
    if (!rotate && previous.theme == theme)
      for (final id in previous.ids)
        if (available[readingIdentity(id)] case final item?
            when matches(item, theme))
          item,
  ];
  if (!rotate) {
    return (
      DiscoveryPage(theme, List.unmodifiable(picks)),
      DiscoveryMemory(
        day: day,
        cycle: cycle,
        theme: theme,
        ids: picks.map((item) => item.identity).toList(growable: false),
        recentIds: previous.recentIds,
      ),
    );
  }
  final pickedIds = picks.map((item) => item.identity).toSet();
  final recent = {
    ...recentIds.map(readingIdentity),
    ...?previous?.recentIds.map(readingIdentity),
    ...?previous?.ids.map(readingIdentity),
  };
  final remaining =
      available.values
          .where(
            (item) =>
                matches(item, theme) && !pickedIds.contains(item.identity),
          )
          .toList()
        ..sort((a, b) {
          final order = _hash('$seed:${a.identity}')
              .compareTo(_hash('$seed:${b.identity}'));
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  // Round-robin across libraries, taking fresh suggestions before repeats.
  for (final repeated in [false, true]) {
    final libraries = <String?, List<CatalogueItem>>{};
    for (final item in remaining) {
      if (recent.contains(item.identity) == repeated) {
        (libraries[item.libraryId] ??= []).add(item);
      }
    }
    while (libraries.isNotEmpty && picks.length < DiscoveryMemory.maxItems) {
      for (final library in libraries.keys.toList()) {
        if (picks.length == DiscoveryMemory.maxItems) break;
        final items = libraries[library]!;
        picks.add(items.removeAt(0));
        if (items.isEmpty) libraries.remove(library);
      }
    }
  }
  final ids = picks.map((item) => item.identity).toList(growable: false);
  final history = <String>{
    ...?previous?.recentIds.where((id) => !(previous.ids.contains(id))),
    ...?previous?.ids,
  }.toList();
  final memory = DiscoveryMemory(
    day: day,
    cycle: cycle,
    theme: theme,
    ids: ids,
    recentIds: history
        .skip(
          (history.length - DiscoveryMemory.maxRecent).clamp(0, history.length),
        )
        .toList(),
  );
  return (DiscoveryPage(theme, List.unmodifiable(picks)), memory);
}

/// Coordinate three rows from one metadata pool, preserving saved identities
/// within the launch day and reserving them while adopting older single rows.
(List<DiscoveryPage>, List<DiscoveryMemory>) selectDiscoverySections({
  required Iterable<CatalogueItem> candidates,
  required List<ResumeEntry> resume,
  required String accountId,
  required DateTime now,
  Iterable<String> readingGenres = const [],
  List<DiscoveryMemory> previous = const [],
}) {
  final pages = <DiscoveryPage>[];
  final memories = <DiscoveryMemory>[];
  final picked = <String>{};
  final themes = <DiscoveryTheme>{};
  for (var index = 0; index < DiscoveryPage.sectionCount; index++) {
    final stored = index < previous.length ? previous[index] : null;
    final reserved = <String>{
      for (var other = 0; other < previous.length; other++)
        if (other != index && previous[other].day == discoveryDay(now))
          ...previous[other].ids,
    };
    final (page, memory) = selectDiscovery(
      candidates: candidates,
      resume: resume,
      readingGenres: readingGenres,
      excludedIds: {...picked, ...reserved},
      excludedThemes: themes,
      recentIds: previous.expand(
        (memory) => [...memory.ids, ...memory.recentIds],
      ),
      accountId: index == 0 ? accountId : '$accountId:section-$index',
      now: now,
      previous: stored,
    );
    final repeatedTheme = themes.contains(page.theme);
    pages.add(
      DiscoveryPage(
        page.theme,
        page.items,
        fallbackLabel: repeatedTheme
            ? (index == 1 ? 'From your libraries' : 'More to explore')
            : null,
      ),
    );
    memories.add(memory);
    picked.addAll(memory.ids);
    themes.add(page.theme);
  }
  return (List.unmodifiable(pages), memories);
}

int _hash(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash + unit) & 0x3fffffff;
    hash = (hash + (hash << 10)) & 0x3fffffff;
    hash ^= hash >> 6;
  }
  hash = (hash + (hash << 3)) & 0x3fffffff;
  hash ^= hash >> 11;
  return (hash + (hash << 15)) & 0x3fffffff;
}

/// Adopt older discovery rows that stored only series remote IDs.
String readingIdentity(String stored) =>
    stored.startsWith('series:') || stored.startsWith('book:')
    ? stored
    : 'series:$stored';
