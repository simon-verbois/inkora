import '../domain/catalogue_filters.dart';

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_metadata.dart';
import '../domain/resume_entry.dart';
import '../domain/volume_progress.dart';
import 'library_visibility_store.dart';

final class CatalogueStore {
  CatalogueStore(
    this.database,
    this.accountId, {
    this.applyLibraryVisibility = true,
  });
  final bool applyLibraryVisibility;
  LibraryVisibilityStore get visibility =>
      LibraryVisibilityStore(database, accountId);
  String _visible(String alias) =>
      applyLibraryVisibility ? LibraryVisibilityStore.predicate(alias) : '1';
  final AppDatabase database;
  final String accountId;

  /// SQL projection stays inside the published account/generation. A series
  /// containing only documents is replaced by its individual ebook books;
  /// mixed series retain their raster grouping alongside those ebooks.
  static String readingUnitsPredicate(String alias) =>
      """
    (($alias.kind = 'book' AND ${ebookPredicate(alias)}) OR
     ($alias.kind = 'series' AND (NOT EXISTS (
       SELECT 1 FROM catalogue_entries child
       WHERE child.account_id=$alias.account_id AND child.generation=$alias.generation
         AND child.kind='book' AND child.series_id=$alias.remote_id
         AND ${ebookPredicate('child')}) OR EXISTS (
       SELECT 1 FROM catalogue_entries child
       WHERE child.account_id=$alias.account_id AND child.generation=$alias.generation
         AND child.kind='book' AND child.series_id=$alias.remote_id
         AND NOT ${ebookPredicate('child')}))))
  """;

  static String ebookPredicate(String alias) =>
      "COALESCE(json_extract($alias.descriptive_metadata, '\$.mediaType'), '') IN ('application/epub+zip', 'application/pdf')";

  /// One upgrade refresh fills additive metadata fields in older snapshots
  /// (media type, reading status and the in-progress server page).
  Future<bool> needsMediaRefresh() async {
    final active = await snapshot();
    if (active == null) return false;
    final rows = await database
        .customSelect(
          "SELECT 1 FROM catalogue_entries WHERE account_id=? AND generation=? AND kind='book' AND available=1 AND (json_type(descriptive_metadata, '\$.mediaType') IS NULL OR json_type(descriptive_metadata, '\$.readingStatus') IS NULL OR (json_extract(descriptive_metadata, '\$.readingStatus')='inProgress' AND json_type(descriptive_metadata, '\$.readPage') IS NULL)) LIMIT 1",
          variables: [Variable(accountId), Variable(active.generation)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<CatalogueSnapshot?> snapshot() => (database.select(
    database.catalogueSnapshots,
  )..where((row) => row.accountId.equals(accountId))).getSingleOrNull();

  Stream<void> _changes() => database
      .customSelect(
        '''SELECT s.generation, s.updated_at,
      (SELECT payload FROM app_preferences WHERE key=?) AS visibility
      FROM (SELECT 1) seed LEFT JOIN catalogue_snapshots s ON s.account_id=?''',
        variables: [Variable(visibility.key), Variable(accountId)],
        readsFrom: {
          database.catalogueSnapshots,
          if (applyLibraryVisibility) database.appPreferences,
        },
      )
      .watchSingle()
      .map(
        (row) => (
          row.readNullable<String>('generation'),
          row.readNullable<String>('updated_at'),
          applyLibraryVisibility
              ? row.readNullable<String>('visibility')
              : null,
        ),
      )
      .distinct()
      .map((_) {});

  Stream<void> watchPublications() => _changes();

  /// Merge narrowly observed publication/selection changes with reading writes.
  /// Other app preferences (including discovery's own writes) do not emit.
  Stream<void> watchReadingChanges({bool includeServerShelf = false}) =>
      Stream<void>.multi((controller) {
        final publications = watchPublications().listen(
          controller.add,
          onError: controller.addError,
        );
        final reading = watchTables(database, {
          if (includeServerShelf) database.resumeSnapshots,
          database.readerPositions,
          database.readerManifests,
          database.progressEvents,
          database.progressHeads,
        }).listen(controller.add, onError: controller.addError);
        controller.onCancel = () async {
          await publications.cancel();
          await reading.cancel();
        };
      });

  Stream<List<CatalogueItem>> watchAvailableLibraries() => _changes().asyncMap(
    (_) => database
        .customSelect(
          '''SELECT e.*, 0 AS membership_removed FROM catalogue_entries e
      JOIN catalogue_snapshots s ON s.account_id=e.account_id AND s.generation=e.generation
      WHERE e.account_id=? AND e.kind='library' AND e.available=1 AND e.deleted=0
      ORDER BY e.sort_title, e.remote_id''',
          variables: [Variable(accountId)],
        )
        .get()
        .then((rows) => rows.map(_item).toList(growable: false)),
  );

  /// Komga book metadata may omit genres; read them from the cached series.
  Future<Set<String>> discoveryReadingGenres(Set<String> seriesIds) async {
    final active = await snapshot();
    if (active == null || seriesIds.isEmpty) return {};
    final ids = seriesIds.toList(growable: false);
    final genres = <String>{};
    for (var offset = 0; offset < ids.length; offset += 200) {
      final batch = ids.skip(offset).take(200).toList(growable: false);
      final rows = await database
          .customSelect(
            '''SELECT descriptive_metadata FROM catalogue_entries
           WHERE account_id = ? AND generation = ? AND kind = 'series'
             AND remote_id IN (${List.filled(batch.length, '?').join(',')})''',
            variables: [
              Variable(accountId),
              Variable(active.generation),
              ...batch.map(Variable.new),
            ],
          )
          .get();
      for (final row in rows) {
        genres.addAll(
          CatalogueMetadata.fromJson(
            jsonDecode(row.read<String>('descriptive_metadata'))
                as Map<String, dynamic>,
          ).genres,
        );
      }
    }
    return genres;
  }

  /// A bounded, metadata-only random sample of the whole published catalogue.
  /// Retained picks always participate, even outside the new random sample.
  Future<List<CatalogueItem>> discoveryCandidates(
    List<String> retainedIds, {
    bool sample = true,
  }) async {
    if (retainedIds.length > 30) throw ArgumentError.value(retainedIds);
    if (!sample && retainedIds.isEmpty) return [];
    final active = await snapshot();
    if (active == null) return [];
    final seriesIds = <String>[];
    final bookIds = <String>[];
    for (final id in retainedIds) {
      if (id.startsWith('book:')) {
        bookIds.add(id.substring(5));
      } else {
        seriesIds.add(id.startsWith('series:') ? id.substring(7) : id);
      }
    }
    // Keep same-day restoration on the existing kind/remote-ID primary key.
    final retainedWhere = [
      if (seriesIds.isNotEmpty)
        "(e.kind='series' AND e.remote_id IN (${List.filled(seriesIds.length, '?').join(',')}))",
      if (bookIds.isNotEmpty)
        "(e.kind='book' AND e.remote_id IN (${List.filled(bookIds.length, '?').join(',')}))",
    ].join(' OR ');
    final retained = !sample || retainedIds.isEmpty
        ? ''
        : 'CASE WHEN ($retainedWhere) THEN 0 ELSE 1 END,';
    final rows = await database
        .customSelect(
          '''SELECT e.kind, e.remote_id, e.title, e.library_id, e.series_id,
                    e.item_count, e.modified, e.descriptive_metadata
         FROM catalogue_entries e
         WHERE e.account_id = ? AND e.generation = ?
           AND ${readingUnitsPredicate('e')}
           AND e.available = 1 AND e.deleted = 0 AND ${_visible('e')}
           ${sample ? '' : 'AND ($retainedWhere)'}
         ORDER BY $retained ${sample ? 'random()' : 'e.remote_id'} LIMIT ?''',
          variables: [
            Variable(accountId),
            Variable(active.generation),
            ...seriesIds.map(Variable.new),
            ...bookIds.map(Variable.new),
            Variable((sample ? 400 : 0) + retainedIds.length),
          ],
        )
        .get();
    return rows
        .map(
          (row) => CatalogueItem(
            kind: CatalogueKind.values.byName(row.read<String>('kind')),
            id: row.read<String>('remote_id'),
            title: row.read<String>('title'),
            readingStatus:
                ReadingStatus.values
                    .where(
                      (v) =>
                          v.name ==
                          (jsonDecode(row.read<String>('descriptive_metadata'))
                              as Map)['readingStatus'],
                    )
                    .firstOrNull ??
                ReadingStatus.unread,
            libraryId: row.readNullable<String>('library_id'),
            seriesId: row.readNullable<String>('series_id'),
            itemCount: row.read<int>('item_count'),
            modified: row.read<int>('modified'),
            metadata: CatalogueMetadata.fromJson(
              jsonDecode(row.read<String>('descriptive_metadata'))
                  as Map<String, dynamic>,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> discard(String generation) async {
    await database.transaction(() async {
      await (database.delete(database.catalogueEntries)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.generation.equals(generation),
          ))
          .go();
      await (database.delete(database.catalogueMemberships)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.generation.equals(generation),
          ))
          .go();
    });
  }

  Future<void> stage(String generation, List<CatalogueItem> items) =>
      database.transaction(() async {
        await database.batch((batch) {
          for (final item in items) {
            batch.insert(
              database.catalogueEntries,
              CatalogueEntriesCompanion.insert(
                accountId: accountId,
                generation: generation,
                kind: item.kind.name,
                remoteId: item.id,
                title: item.title,
                sortTitle: item.sortTitle.isEmpty
                    ? item.title.toLowerCase()
                    : item.sortTitle,
                summary: item.summary,
                searchText: item.searchText.isEmpty
                    ? item.title.toLowerCase()
                    : item.searchText,
                libraryId: Value(item.libraryId),
                seriesId: Value(item.seriesId),
                number: item.number,
                itemCount: item.itemCount,
                pageCount: item.pageCount,
                modified: item.modified,
                deleted: item.deleted,
                available: item.available,
                ordered: item.ordered,
                descriptiveMetadata: Value(
                  jsonEncode({
                    ...item.metadata.toJson(),
                    'readingStatus': item.readingStatus.name,
                    'readPage': ?item.readPage,
                    'readModified': ?item.readModified,
                  }),
                ),
              ),
            );
            for (var i = 0; i < item.members.length; i++) {
              batch.insert(
                database.catalogueMemberships,
                CatalogueMembershipsCompanion.insert(
                  accountId: accountId,
                  generation: generation,
                  groupKind: item.kind.name,
                  groupId: item.id,
                  itemKind: item.kind == CatalogueKind.collection
                      ? 'series'
                      : 'book',
                  itemId: item.members[i],
                  position: i,
                  removed: false,
                ),
              );
            }
          }
        });
      });

  /// Publish all kinds together, retaining unavailable rows and historical memberships.
  Future<void> publish(
    String generation,
    DateTime now,
    bool Function() canCommit,
  ) => database.transaction(() async {
    if (!canCommit()) throw StateError('Snapshot cancelled');
    final old = await snapshot();
    if (old != null) {
      await database.customStatement(
        '''
        INSERT INTO catalogue_entries
        SELECT o.account_id, ?, o.kind, o.remote_id, o.title, o.sort_title, o.summary,
          o.search_text, o.library_id, o.series_id, o.number, o.item_count, o.page_count,
          o.modified, o.deleted, 0, o.ordered, o.descriptive_metadata
        FROM catalogue_entries o
        WHERE o.account_id = ? AND o.generation = ? AND NOT EXISTS (
          SELECT 1 FROM catalogue_entries n WHERE n.account_id = o.account_id
          AND n.generation = ? AND n.kind = o.kind AND n.remote_id = o.remote_id)
      ''',
        [generation, accountId, old.generation, generation],
      );
      await database.customStatement(
        '''
        INSERT INTO catalogue_memberships
        SELECT o.account_id, ?, o.group_kind, o.group_id, o.item_kind, o.item_id, o.position, 1
        FROM catalogue_memberships o WHERE o.account_id = ? AND o.generation = ?
        AND NOT EXISTS (SELECT 1 FROM catalogue_memberships n WHERE n.account_id = o.account_id
          AND n.generation = ? AND n.group_kind = o.group_kind AND n.group_id = o.group_id
          AND n.item_id = o.item_id)
      ''',
        [generation, accountId, old.generation, generation],
      );
    }
    // Missing targets remain visible even if this client has never seen their metadata.
    await database.customStatement(
      '''
      INSERT OR IGNORE INTO catalogue_entries
      SELECT m.account_id, m.generation, m.item_kind, m.item_id,
        'Unavailable item', 'unavailable item', '', 'unavailable item', NULL, NULL,
        0, 0, 0, 0, 0, 0, 0, '{}'
      FROM catalogue_memberships m WHERE m.account_id = ? AND m.generation = ?
    ''',
      [accountId, generation],
    );
    if (!canCommit()) throw StateError('Snapshot cancelled');
    await database
        .into(database.catalogueSnapshots)
        .insertOnConflictUpdate(
          CatalogueSnapshotsCompanion.insert(
            accountId: accountId,
            generation: generation,
            updatedAt: now,
          ),
        );
    await (database.delete(database.catalogueEntries)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.generation.equals(generation).not(),
        ))
        .go();
    await (database.delete(database.catalogueMemberships)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.generation.equals(generation).not(),
        ))
        .go();
    if (!canCommit()) throw StateError('Snapshot cancelled');
  });

  Future<void> cleanAbandoned() => database.transaction(() async {
    final active = await snapshot();
    for (final table in ['catalogue_entries', 'catalogue_memberships']) {
      await database.customStatement(
        'DELETE FROM $table WHERE account_id = ? ${active == null ? '' : 'AND generation <> ?'}',
        [accountId, if (active != null) active.generation],
      );
    }
  });

  Stream<LocalCataloguePage> watch(CatalogueQuery query) =>
      _queryChanges(query).asyncMap((_) => read(query));

  /// Re-reads the whole retained prefix only when a generation is published;
  /// [limit] is evaluated per publication so appended batches stay included.
  Stream<LocalCataloguePage> watchWindow(
    CatalogueQuery query,
    int Function() limit,
  ) => _queryChanges(query).asyncMap((_) => read(query, itemLimit: limit()));

  Stream<void> _queryChanges(CatalogueQuery query) {
    if (query.filters.readingStatus == ReadingStatus.any &&
        !query.filters.downloadedOnly) {
      return _changes();
    }
    return Stream<void>.multi((controller) {
      final publication = _changes().listen(
        controller.add,
        onError: controller.addError,
      );
      final reading = watchTables(database, {
        if (query.filters.readingStatus != ReadingStatus.any) ...{
          database.bookReadingStates,
          database.resumeSnapshots,
        },
        if (query.filters.downloadedOnly) database.readerDownloads,
      }).listen(controller.add, onError: controller.addError);
      controller.onCancel = () async {
        await publication.cancel();
        await reading.cancel();
      };
    });
  }

  /// Latest explicit local intent wins; then acknowledged state and server shelf.
  /// Correlated lookups use account/book primary keys, before count/pagination.
  static String readingState(
    String alias, {
    String id = 'remote_id',
    String? metadata,
  }) =>
      """COALESCE(
    (SELECT CASE WHEN v.operation='markUnread' THEN 'unread' WHEN v.operation='complete' OR (v.document_locator IS NOT NULL AND json_extract(v.document_locator, '\$.locations.totalProgression')>=0.99) OR (v.document_locator IS NULL AND v.page_index>=v.page_count-1) THEN 'completed' ELSE 'inProgress' END
      FROM progress_events v WHERE v.account_id=$alias.account_id AND v.book_id=$alias.$id ORDER BY v.sequence DESC LIMIT 1),
    (SELECT CASE WHEN json_extract(h.baseline, '\$.completed')=1 THEN 'completed' WHEN json_extract(h.baseline, '\$.page') IS NOT NULL THEN 'inProgress' ELSE 'unread' END
      FROM progress_heads h WHERE h.account_id=$alias.account_id AND h.book_id=$alias.$id AND h.baseline IS NOT NULL),
    (SELECT 'inProgress' FROM reader_positions p WHERE p.account_id=$alias.account_id AND p.book_id=$alias.$id),
    (SELECT 'inProgress' FROM resume_snapshots r, json_each(r.payload, '\$.books') shelf_book WHERE r.account_id=$alias.account_id AND json_extract(shelf_book.value, '\$.id')=$alias.$id LIMIT 1), json_extract(${metadata ?? '$alias.descriptive_metadata'}, '\$.readingStatus'), 'unread')""";

  Future<LocalCataloguePage> read(
    CatalogueQuery query, {
    int? itemLimit,
    int itemOffset = 0,
  }) => database.transaction(() async {
    if (query.page < 0 ||
        query.pageSize < 1 ||
        query.pageSize > 200 ||
        (itemLimit != null && itemLimit < 1) ||
        itemOffset < 0 ||
        (query.groupId == null) != (query.groupKind == null)) {
      throw ArgumentError('Invalid catalogue query');
    }
    if (query.readingUnits && query.kind != CatalogueKind.series) {
      throw ArgumentError(
        'Reading-unit queries require the series browse scope',
      );
    }
    final active = await snapshot();
    if (active == null) return const LocalCataloguePage([], 0, null);
    final (:join, :where, :args) = _scope(query, active.generation);
    final count = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM catalogue_entries e $join WHERE $where',
          variables: args,
        )
        .getSingle();
    final order = switch (query.sort) {
      CatalogueSort.title => 'e.sort_title ASC',
      CatalogueSort.titleDescending => 'e.sort_title DESC',
      CatalogueSort.recentlyUpdated => 'e.modified DESC',
      CatalogueSort.sequence =>
        query.groupId != null
            ? 'm.removed ASC, m.position ASC'
            : 'e.number ASC, e.sort_title ASC',
    };
    final rows = await database
        .customSelect(
          'SELECT e.*, ${query.groupId == null ? '0' : 'm.removed'} AS membership_removed FROM catalogue_entries e $join WHERE $where ORDER BY $order, e.remote_id ASC, e.kind ASC LIMIT ? OFFSET ?',
          variables: [
            ...args,
            Variable(itemLimit ?? query.pageSize),
            Variable(
              itemLimit == null ? query.page * query.pageSize : itemOffset,
            ),
          ],
        )
        .get();
    return LocalCataloguePage(
      rows.map(_item).toList(growable: false),
      count.read<int>('total'),
      active.updatedAt,
    );
  });

  /// Result count of [query] for the filter sheet's "Show results" button:
  /// the same indexed scope and COUNT as [read], without loading any row.
  Future<int> count(CatalogueQuery query) => database.transaction(() async {
    if ((query.groupId == null) != (query.groupKind == null) ||
        (query.readingUnits && query.kind != CatalogueKind.series)) {
      throw ArgumentError('Invalid catalogue query');
    }
    final active = await snapshot();
    if (active == null) return 0;
    final (:join, :where, :args) = _scope(query, active.generation);
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM catalogue_entries e $join WHERE $where',
          variables: args,
        )
        .getSingle();
    return row.read<int>('total');
  });

  /// Parent lookup uses the account/generation/kind/remote identity index.
  /// JSON predicates run only in the selected published scope, on filter changes.
  String _facetValue(CatalogueFacet facet) {
    final path = '\$.${facet.name}';
    final own = "json_extract(e.descriptive_metadata, '$path')";
    final parent =
        "(SELECT json_extract(p.descriptive_metadata, '$path') FROM catalogue_entries p WHERE p.account_id=e.account_id AND p.generation=e.generation AND p.kind='series' AND p.remote_id=e.series_id)";
    return "COALESCE(NULLIF(NULLIF(CAST($own AS TEXT), ''), '[]'), $parent)";
  }

  ({String join, String where, List<Variable<Object>> args}) _scope(
    CatalogueQuery query,
    String generation, {
    bool applyFilters = true,
  }) {
    final args = <Variable<Object>>[
      Variable(accountId),
      Variable(generation),
      if (!query.readingUnits) Variable(query.kind.name),
    ];
    var join = '';
    var where =
        "e.account_id = ? AND e.generation = ? AND ${query.readingUnits ? readingUnitsPredicate('e') : 'e.kind = ?'} AND ${_visible('e')}";
    if (query.groupId != null) {
      final target = query.readingUnits
          ? "m.item_kind='series' AND m.item_id=CASE WHEN e.kind='book' THEN e.series_id ELSE e.remote_id END"
          : 'm.item_kind=e.kind AND m.item_id=e.remote_id';
      join =
          'JOIN catalogue_memberships m ON m.account_id=e.account_id AND m.generation=e.generation AND $target';
      where += ' AND m.group_kind = ? AND m.group_id = ?';
      args.addAll([Variable(query.groupKind!.name), Variable(query.groupId!)]);
    }
    if (query.libraryId != null) {
      where += ' AND e.library_id = ?';
      args.add(Variable(query.libraryId!));
    }
    if (query.seriesId != null) {
      where += ' AND e.series_id = ?';
      args.add(Variable(query.seriesId!));
    }
    if (!query.showUnavailable) {
      where += ' AND e.available = 1 AND e.deleted = 0';
      if (query.groupId != null) where += ' AND m.removed = 0';
    }
    // Bound variables and literal substring matching keep SQL/wildcard input harmless.
    for (final term
        in query.search
            .toLowerCase()
            .trim()
            .split(RegExp(r'\s+'))
            .where((term) => term.isNotEmpty)) {
      where += ' AND instr(e.search_text, ?) > 0';
      args.add(Variable(term));
    }
    if (applyFilters) {
      if (query.filters.readingStatus != ReadingStatus.any ||
          query.filters.downloadedOnly) {
        final child =
            "b.account_id=e.account_id AND b.generation=e.generation AND b.kind='book' AND b.series_id=e.remote_id AND b.available=1 AND b.deleted=0 AND NOT ${ebookPredicate('b')}";
        if (query.filters.readingStatus != ReadingStatus.any) {
          final status = query.filters.readingStatus;
          final book = readingState('e');
          final state = readingState('b');
          final series = switch (status) {
            ReadingStatus.unread =>
              "NOT EXISTS (SELECT 1 FROM catalogue_entries b WHERE $child AND $state<>'unread')",
            ReadingStatus.completed =>
              "EXISTS (SELECT 1 FROM catalogue_entries b WHERE $child) AND NOT EXISTS (SELECT 1 FROM catalogue_entries b WHERE $child AND $state<>'completed')",
            _ =>
              "EXISTS (SELECT 1 FROM catalogue_entries b WHERE $child AND $state<>'unread') AND EXISTS (SELECT 1 FROM catalogue_entries b WHERE $child AND $state<>'completed')",
          };
          where +=
              " AND ((e.kind='book' AND $book=?) OR (e.kind='series' AND ($series)))";
          args.add(Variable(status.name));
        }
        if (query.filters.downloadedOnly) {
          where +=
              " AND ((e.kind='book' AND EXISTS (SELECT 1 FROM reader_downloads d WHERE d.account_id=e.account_id AND d.book_id=e.remote_id)) OR (e.kind='series' AND EXISTS (SELECT 1 FROM catalogue_entries b JOIN reader_downloads d ON d.account_id=b.account_id AND d.book_id=b.remote_id WHERE $child)))";
        }
      }
      for (final entry in query.filters.values.entries) {
        final value = _facetValue(entry.key);
        if (entry.key == CatalogueFacet.mediaType) {
          where +=
              " AND ((e.kind<>'series' AND CAST($value AS TEXT)=?) OR (e.kind='series' AND EXISTS (SELECT 1 FROM catalogue_entries format_book WHERE format_book.account_id=e.account_id AND format_book.generation=e.generation AND format_book.kind='book' AND format_book.series_id=e.remote_id AND json_extract(format_book.descriptive_metadata, '\$.mediaType')=?)))";
          args.addAll([Variable(entry.value), Variable(entry.value)]);
          continue;
        }
        where += entry.key.multiple
            ? " AND EXISTS (SELECT 1 FROM json_each($value) f WHERE ${entry.key == CatalogueFacet.authors ? "json_extract(f.value, '\$.name')" : 'f.value'} = ?)"
            : ' AND CAST($value AS TEXT) = ?';
        args.add(Variable(entry.value));
      }
    }
    return (join: join, where: where, args: args);
  }

  /// One SQL aggregation per dimension, only while opening the filter sheet.
  /// No full catalogue objects or growing page prefix are loaded into Dart.
  Future<CatalogueFacets> facets(
    CatalogueQuery query,
  ) => database.transaction(() async {
    final active = await snapshot();
    if (active == null) return {};
    final (:join, :where, :args) = _scope(
      query,
      active.generation,
      applyFilters: false,
    );
    final result = <CatalogueFacet, List<String>>{};
    for (final facet in CatalogueFacet.values) {
      final expression = _facetValue(facet);
      final formats =
          "CASE WHEN e.kind='series' THEN (SELECT json_group_array(DISTINCT json_extract(format_book.descriptive_metadata, '\$.mediaType')) FROM catalogue_entries format_book WHERE format_book.account_id=e.account_id AND format_book.generation=e.generation AND format_book.kind='book' AND format_book.series_id=e.remote_id) ELSE json_array($expression) END";
      final value = facet == CatalogueFacet.mediaType
          ? 'f.value'
          : facet.multiple
          ? facet == CatalogueFacet.authors
                ? "json_extract(f.value, '\$.name')"
                : 'f.value'
          : expression;
      final rows = await database
          .customSelect(
            "SELECT DISTINCT CAST($value AS TEXT) AS value FROM catalogue_entries e $join ${facet == CatalogueFacet.mediaType
                ? 'JOIN json_each($formats) f'
                : facet.multiple
                ? 'JOIN json_each($expression) f'
                : ''} WHERE $where AND $value IS NOT NULL AND CAST($value AS TEXT) <> '' ORDER BY value COLLATE NOCASE",
            variables: args,
          )
          .get();
      if (rows.isNotEmpty) {
        result[facet] = rows.map((r) => r.read<String>('value')).toList();
      }
    }
    return result;
  });

  CatalogueItem _item(QueryRow row) {
    final descriptive = jsonDecode(
      row.read<String>('descriptive_metadata'),
    ) as Map<String, dynamic>;
    return _itemFrom(row, descriptive);
  }

  CatalogueItem _itemFrom(QueryRow row, Map<String, dynamic> descriptive) =>
      CatalogueItem(
        kind: CatalogueKind.values.byName(row.read<String>('kind')),
        id: row.read<String>('remote_id'),
        title: row.read<String>('title'),
        readingStatus:
            ReadingStatus.values
                .where((v) => v.name == descriptive['readingStatus'])
                .firstOrNull ??
            ReadingStatus.unread,
        readPage: descriptive['readPage'] as int?,
        readModified: descriptive['readModified'] as String?,
        sortTitle: row.read<String>('sort_title'),
        summary: row.read<String>('summary'),
        metadata: CatalogueMetadata.fromJson({
          ...descriptive,
          if (row.data['document_type'] case final String type)
            'mediaType': type,
        }),
        searchText: row.read<String>('search_text'),
        libraryId: row.readNullable<String>('library_id'),
        seriesId: row.readNullable<String>('series_id'),
        number: row.read<double>('number'),
        itemCount: row.read<int>('item_count'),
        pageCount: row.read<int>('page_count'),
        modified: row.read<int>('modified'),
        deleted: row.read<bool>('deleted'),
        available: row.read<bool>('available'),
        ordered: row.read<bool>('ordered'),
        membershipRemoved: row.read<bool>('membership_removed'),
      );

  Stream<Map<CatalogueKind, int>> overview() => _changes().asyncMap(
    (_) => database.transaction(() async {
      final active = await snapshot();
      if (active == null) return <CatalogueKind, int>{};
      final rows = await database
          .customSelect(
            'SELECT e.kind, COUNT(*) AS total FROM catalogue_entries e WHERE e.account_id=? AND e.generation=? AND e.available=1 AND e.deleted=0 AND ${_visible('e')} GROUP BY e.kind',
            variables: [Variable(accountId), Variable(active.generation)],
          )
          .get();
      return {
        for (final row in rows)
          CatalogueKind.values.byName(row.read<String>('kind')): row.read<int>(
            'total',
          ),
      };
    }),
  );

  Stream<CatalogueItem?> item(
    CatalogueKind kind,
    String id,
  ) => _changes().asyncMap(
    (_) => database.transaction(() async {
      final active = await snapshot();
      if (active == null) return null;
      final rows = await database
          .customSelect(
            'SELECT e.*, 0 AS membership_removed FROM catalogue_entries e WHERE e.account_id=? AND e.generation=? AND e.kind=? AND e.remote_id=? AND ${_visible('e')}',
            variables: [
              Variable(accountId),
              Variable(active.generation),
              Variable(kind.name),
              Variable(id),
            ],
          )
          .get();
      return rows.isEmpty ? null : _item(rows.single);
    }),
  );

  /// Lean, ordered volume rows of one series. Re-read only when a catalogue
  /// generation or library selection is published; descriptive JSON fields
  /// are extracted by SQLite on the database isolate, never decoded here.
  Stream<List<SeriesVolume>> watchSeriesVolumes(String seriesId) =>
      _changes().asyncMap((_) => readSeriesVolumes(seriesId));

  Future<List<SeriesVolume>> readSeriesVolumes(String seriesId) async {
    final rows = await database
        .customSelect(
          '''SELECT e.remote_id, e.title, e.library_id, e.number, e.page_count,
            e.modified, e.available, e.deleted,
            json_extract(e.descriptive_metadata, '\$.mediaType') AS media_type,
            json_extract(e.descriptive_metadata, '\$.readingStatus') AS server_status,
            json_extract(e.descriptive_metadata, '\$.readPage') AS server_page,
            json_extract(e.descriptive_metadata, '\$.readModified') AS server_modified
          FROM catalogue_snapshots s
          JOIN catalogue_entries e ON e.account_id=s.account_id AND e.generation=s.generation
          WHERE s.account_id=? AND e.kind='book' AND e.series_id=? AND ${_visible('e')}
          ORDER BY e.number, e.sort_title, e.remote_id''',
          variables: [Variable(accountId), Variable(seriesId)],
        )
        .get();
    return [
      for (final row in rows)
        SeriesVolume(
          id: row.read<String>('remote_id'),
          seriesId: seriesId,
          title: row.read<String>('title'),
          libraryId: row.readNullable<String>('library_id'),
          number: row.read<double>('number'),
          pageCount: row.read<int>('page_count'),
          modified: row.read<int>('modified'),
          available: row.read<bool>('available') && !row.read<bool>('deleted'),
          mediaType: row.readNullable<String>('media_type') ?? '',
          serverStatus:
              ReadingStatus.values
                  .where(
                    (v) => v.name == row.readNullable<String>('server_status'),
                  )
                  .firstOrNull ??
              ReadingStatus.unread,
          serverPage: row.readNullable<int>('server_page'),
          serverModified: row.readNullable<String>('server_modified'),
        ),
    ];
  }

  /// Device progress of one series' books (latest outbox intent, observed
  /// baseline, exact reader position). It wakes on local reading writes, but
  /// emits only when a book's effective inputs change; every lookup uses the
  /// progress tables' account/book primary keys.
  Stream<Map<String, LocalVolumeProgress>> watchSeriesLocalProgress(
    String seriesId,
  ) => database
      .customSelect(
        '''SELECT e.remote_id AS book_id, v.operation, v.page_index AS event_page,
          v.page_count AS event_count,
          json_extract(v.document_locator, '\$.locations.totalProgression') AS event_total,
          h.baseline IS NOT NULL AS has_baseline,
          COALESCE(json_extract(h.baseline, '\$.completed'), 0) AS baseline_completed,
          json_extract(h.baseline, '\$.page') AS baseline_page,
          p.page_index AS position_page,
          EXISTS (SELECT 1 FROM progress_events c WHERE c.account_id=e.account_id
            AND c.book_id=e.remote_id AND c.state='conflict') AS conflict
        FROM catalogue_snapshots s
        JOIN catalogue_entries e ON e.account_id=s.account_id AND e.generation=s.generation
        LEFT JOIN progress_events v ON v.account_id=e.account_id AND v.book_id=e.remote_id
          AND v.sequence=(SELECT MAX(x.sequence) FROM progress_events x
            WHERE x.account_id=e.account_id AND x.book_id=e.remote_id)
        LEFT JOIN progress_heads h ON h.account_id=e.account_id AND h.book_id=e.remote_id
        LEFT JOIN reader_positions p ON p.account_id=e.account_id AND p.book_id=e.remote_id
        WHERE s.account_id=? AND e.kind='book' AND e.series_id=?
          AND (v.book_id IS NOT NULL OR h.baseline IS NOT NULL OR p.book_id IS NOT NULL)''',
        variables: [Variable(accountId), Variable(seriesId)],
        readsFrom: {
          database.catalogueSnapshots,
          database.progressEvents,
          database.progressHeads,
          database.readerPositions,
        },
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<String>('book_id'): LocalVolumeProgress(
              operation: row.readNullable<String>('operation'),
              eventPage: row.readNullable<int>('event_page'),
              eventPageCount: row.readNullable<int>('event_count'),
              eventTotal: row.readNullable<double>('event_total'),
              hasBaseline: row.read<bool>('has_baseline'),
              baselineCompleted: row.read<int>('baseline_completed') == 1,
              baselinePage: row.readNullable<int>('baseline_page'),
              positionPage: row.readNullable<int>('position_page'),
              conflict: row.read<bool>('conflict'),
            ),
        },
      )
      .distinct(sameProgress);

  /// Value equality of two [watchSeriesLocalProgress] results.
  static bool sameProgress(
    Map<String, LocalVolumeProgress> a,
    Map<String, LocalVolumeProgress> b,
  ) =>
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  Future<List<ResumeEntry>> visibleResume(List<ResumeEntry> entries) async {
    final visible = await libraryVisibility();
    return entries
        .where((entry) => visible(entry.item.libraryId))
        .toList(growable: false);
  }

  /// Whether a book of a library may be shown: not a revoked library and,
  /// with an explicit local selection, a selected one. Two small reads.
  Future<bool Function(String? libraryId)> libraryVisibility() async {
    if (!applyLibraryVisibility) return (_) => true;
    final selected = LibraryVisibilityStore.decode(await visibility.payload());
    final active = await snapshot();
    final denied = active == null
        ? <String>{}
        : (await database
                  .customSelect(
                    "SELECT remote_id FROM catalogue_entries WHERE account_id=? AND generation=? AND kind='library' AND (available=0 OR deleted=1)",
                    variables: [
                      Variable(accountId),
                      Variable(active.generation),
                    ],
                  )
                  .get())
              .map((row) => row.read<String>('remote_id'))
              .toSet();
    return (String? library) =>
        !denied.contains(library) &&
        (selected == null || selected.contains(library));
  }

  /// Saved local positions with a matching raster manifest; title-ordered because
  /// the existing locator schema has no cross-book activity timestamp.
  Stream<List<ResumeEntry>> resume() =>
      watchReadingChanges().asyncMap((_) => readResume());

  Future<List<ResumeEntry>> readResume() async =>
      _resumeRows(await _resumeQuery().get());

  Future<Map<String, String>> resumeSeriesTitles(Set<String> ids) async {
    final active = await snapshot();
    if (active == null || ids.isEmpty) return {};
    final rows =
        await (database.select(database.catalogueEntries)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.generation.equals(active.generation) &
                  row.kind.equals('series') &
                  row.remoteId.isIn(ids),
            ))
            .get();
    return {for (final row in rows) row.remoteId: row.title};
  }

  Selectable<QueryRow> _resumeQuery() => database.customSelect(
    '''SELECT e.*, 0 AS membership_removed, p.page_index, p.fraction,
        p.revision AS position_revision,
        json_extract(m.payload, '\$.revision') AS manifest_revision,
        json_extract(m.payload, '\$.accountId') AS manifest_account,
        COALESCE(json_extract(m.payload, '\$.positionCount'), json_array_length(m.payload, '\$.pages')) AS manifest_pages,
        json_extract(m.payload, '\$.documentType') AS document_type,
        json_extract(p.document_locator, '\$.locations.totalProgression') AS ebook_total,
        series.title AS series_title,
        h.baseline, (SELECT operation FROM progress_events v
          WHERE v.account_id=p.account_id AND v.book_id=p.book_id
          ORDER BY v.sequence DESC LIMIT 1) AS pending_operation
      FROM reader_positions p
      JOIN catalogue_snapshots s ON s.account_id=p.account_id
      JOIN catalogue_entries e ON e.account_id=p.account_id AND e.generation=s.generation
        AND e.kind='book' AND e.remote_id=p.book_id
      JOIN reader_manifests m ON m.account_id=p.account_id AND m.book_id=p.book_id
      LEFT JOIN catalogue_entries series ON series.account_id=e.account_id
        AND series.generation=e.generation AND series.kind='series'
        AND series.remote_id=e.series_id
      LEFT JOIN progress_heads h ON h.account_id=p.account_id AND h.book_id=p.book_id
      WHERE p.account_id=? AND e.available=1 AND e.deleted=0 AND ${_visible('e')}
      ORDER BY e.sort_title, e.remote_id LIMIT 40''',
    variables: [Variable(accountId)],
    readsFrom: {
      database.catalogueSnapshots,
      database.readerPositions,
      database.readerManifests,
      database.progressEvents,
      database.progressHeads,
    },
  );

  List<ResumeEntry> _resumeRows(List<QueryRow> rows) {
    final result = <ResumeEntry>[];
    for (final row in rows) {
      try {
        // SQLite extracts manifest fields on the database isolate; the full
        // page array is never decoded on the UI isolate for Home.
        final revision = row.read<String>('position_revision');
        final page = row.read<int>('page_index');
        final count = row.readNullable<int>('manifest_pages') ?? 0;
        final operation = row.readNullable<String>('pending_operation');
        final epub =
            row.readNullable<String>('document_type') == 'application/epub+zip';
        final total = row.readNullable<double>('ebook_total');
        final baseline = row.readNullable<String>('baseline');
        if (row.readNullable<String>('manifest_revision') != revision ||
            row.readNullable<String>('manifest_account') != accountId ||
            count < 1 ||
            page < 0 ||
            (epub ? (total ?? 0) >= .99 : page >= count - 1) ||
            operation == 'complete' ||
            operation == 'markUnread') {
          continue;
        }
        if (operation == null &&
            baseline != null &&
            (jsonDecode(baseline) as Map<String, dynamic>)['completed'] ==
                true) {
          continue;
        }
        result.add(
          ResumeEntry(
            item: _item(row),
            seriesTitle:
                row.readNullable<String>('series_title') ?? 'Unknown series',
            pageIndex: page,
            pageCount: count,
            fraction: row.read<double>('fraction').clamp(0, 1),
            raster: !epub,
            totalProgression: total,
          ),
        );
      } catch (_) {
        /* Corrupt saved metadata cannot break the home hub. */
      }
    }
    return result;
  }
}
