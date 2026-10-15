import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/catalogue.dart';
import '../domain/catalogue_metadata.dart';
import '../domain/resume_entry.dart';
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

  /// One upgrade refresh fills the additive metadata field in older snapshots.
  Future<bool> needsMediaRefresh() async {
    final active = await snapshot();
    if (active == null) return false;
    final rows = await database
        .customSelect(
          "SELECT 1 FROM catalogue_entries WHERE account_id=? AND generation=? AND kind='book' AND available=1 AND json_type(descriptive_metadata, '\$.mediaType') IS NULL LIMIT 1",
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
        final reading = database
            .customSelect(
              'SELECT 1',
              readsFrom: {
                if (includeServerShelf) database.resumeSnapshots,
                database.readerPositions,
                database.readerManifests,
                database.progressEvents,
                database.progressHeads,
              },
            )
            .watch()
            .listen((_) => controller.add(null), onError: controller.addError);
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
                descriptiveMetadata: Value(jsonEncode(item.metadata.toJson())),
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
      _changes().asyncMap((_) => read(query));

  /// Re-reads the whole retained prefix only when a generation is published;
  /// [limit] is evaluated per publication so appended batches stay included.
  Stream<LocalCataloguePage> watchWindow(
    CatalogueQuery query,
    int Function() limit,
  ) => _changes().asyncMap((_) => read(query, itemLimit: limit()));

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
    final args = <Variable<Object>>[
      Variable(accountId),
      Variable(active.generation),
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

  CatalogueItem _item(QueryRow row) => CatalogueItem(
    kind: CatalogueKind.values.byName(row.read<String>('kind')),
    id: row.read<String>('remote_id'),
    title: row.read<String>('title'),
    sortTitle: row.read<String>('sort_title'),
    summary: row.read<String>('summary'),
    metadata: CatalogueMetadata.fromJson({
      ...jsonDecode(row.read<String>('descriptive_metadata'))
          as Map<String, dynamic>,
      if (row.data['document_type'] case final String type) 'mediaType': type,
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

  Future<List<ResumeEntry>> visibleResume(List<ResumeEntry> entries) async {
    if (!applyLibraryVisibility) return entries;
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
    return entries
        .where(
          (entry) =>
              !denied.contains(entry.item.libraryId) &&
              (selected == null || selected.contains(entry.item.libraryId)),
        )
        .toList(growable: false);
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
