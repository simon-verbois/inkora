// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServerProfilesTable extends ServerProfiles
    with TableInfo<$ServerProfilesTable, ServerProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, displayName, baseUrl];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
    );
  }

  @override
  $ServerProfilesTable createAlias(String alias) {
    return $ServerProfilesTable(attachedDatabase, alias);
  }
}

class ServerProfile extends DataClass implements Insertable<ServerProfile> {
  final String id;
  final String displayName;
  final String baseUrl;
  const ServerProfile({
    required this.id,
    required this.displayName,
    required this.baseUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['base_url'] = Variable<String>(baseUrl);
    return map;
  }

  ServerProfilesCompanion toCompanion(bool nullToAbsent) {
    return ServerProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      baseUrl: Value(baseUrl),
    );
  }

  factory ServerProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'baseUrl': serializer.toJson<String>(baseUrl),
    };
  }

  ServerProfile copyWith({String? id, String? displayName, String? baseUrl}) =>
      ServerProfile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        baseUrl: baseUrl ?? this.baseUrl,
      );
  ServerProfile copyWithCompanion(ServerProfilesCompanion data) {
    return ServerProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('baseUrl: $baseUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, baseUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.baseUrl == this.baseUrl);
}

class ServerProfilesCompanion extends UpdateCompanion<ServerProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> baseUrl;
  final Value<int> rowid;
  const ServerProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerProfilesCompanion.insert({
    required String id,
    required String displayName,
    required String baseUrl,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       baseUrl = Value(baseUrl);
  static Insertable<ServerProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? baseUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (baseUrl != null) 'base_url': baseUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? baseUrl,
    Value<int>? rowid,
  }) {
    return ServerProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      baseUrl: baseUrl ?? this.baseUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogueEntriesTable extends CatalogueEntries
    with TableInfo<$CatalogueEntriesTable, CatalogueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortTitleMeta = const VerificationMeta(
    'sortTitle',
  );
  @override
  late final GeneratedColumn<String> sortTitle = GeneratedColumn<String>(
    'sort_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<double> number = GeneratedColumn<double>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta(
    'modified',
  );
  @override
  late final GeneratedColumn<int> modified = GeneratedColumn<int>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _availableMeta = const VerificationMeta(
    'available',
  );
  @override
  late final GeneratedColumn<bool> available = GeneratedColumn<bool>(
    'available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("available" IN (0, 1))',
    ),
  );
  static const VerificationMeta _orderedMeta = const VerificationMeta(
    'ordered',
  );
  @override
  late final GeneratedColumn<bool> ordered = GeneratedColumn<bool>(
    'ordered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ordered" IN (0, 1))',
    ),
  );
  static const VerificationMeta _descriptiveMetadataMeta =
      const VerificationMeta('descriptiveMetadata');
  @override
  late final GeneratedColumn<String> descriptiveMetadata =
      GeneratedColumn<String>(
        'descriptive_metadata',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    generation,
    kind,
    remoteId,
    title,
    sortTitle,
    summary,
    searchText,
    libraryId,
    seriesId,
    number,
    itemCount,
    pageCount,
    modified,
    deleted,
    available,
    ordered,
    descriptiveMetadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalogue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sort_title')) {
      context.handle(
        _sortTitleMeta,
        sortTitle.isAcceptableOrUnknown(data['sort_title']!, _sortTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_sortTitleMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('modified')) {
      context.handle(
        _modifiedMeta,
        modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedMeta);
    }
    if (data.containsKey('available')) {
      context.handle(
        _availableMeta,
        available.isAcceptableOrUnknown(data['available']!, _availableMeta),
      );
    } else if (isInserting) {
      context.missing(_availableMeta);
    }
    if (data.containsKey('ordered')) {
      context.handle(
        _orderedMeta,
        ordered.isAcceptableOrUnknown(data['ordered']!, _orderedMeta),
      );
    } else if (isInserting) {
      context.missing(_orderedMeta);
    }
    if (data.containsKey('descriptive_metadata')) {
      context.handle(
        _descriptiveMetadataMeta,
        descriptiveMetadata.isAcceptableOrUnknown(
          data['descriptive_metadata']!,
          _descriptiveMetadataMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountId,
    generation,
    kind,
    remoteId,
  };
  @override
  CatalogueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogueEntry(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sortTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_id'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}number'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      modified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      available: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}available'],
      )!,
      ordered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ordered'],
      )!,
      descriptiveMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descriptive_metadata'],
      )!,
    );
  }

  @override
  $CatalogueEntriesTable createAlias(String alias) {
    return $CatalogueEntriesTable(attachedDatabase, alias);
  }
}

class CatalogueEntry extends DataClass implements Insertable<CatalogueEntry> {
  final String accountId;
  final String generation;
  final String kind;
  final String remoteId;
  final String title;
  final String sortTitle;
  final String summary;
  final String searchText;
  final String? libraryId;
  final String? seriesId;
  final double number;
  final int itemCount;
  final int pageCount;
  final int modified;
  final bool deleted;
  final bool available;
  final bool ordered;
  final String descriptiveMetadata;
  const CatalogueEntry({
    required this.accountId,
    required this.generation,
    required this.kind,
    required this.remoteId,
    required this.title,
    required this.sortTitle,
    required this.summary,
    required this.searchText,
    this.libraryId,
    this.seriesId,
    required this.number,
    required this.itemCount,
    required this.pageCount,
    required this.modified,
    required this.deleted,
    required this.available,
    required this.ordered,
    required this.descriptiveMetadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['generation'] = Variable<String>(generation);
    map['kind'] = Variable<String>(kind);
    map['remote_id'] = Variable<String>(remoteId);
    map['title'] = Variable<String>(title);
    map['sort_title'] = Variable<String>(sortTitle);
    map['summary'] = Variable<String>(summary);
    map['search_text'] = Variable<String>(searchText);
    if (!nullToAbsent || libraryId != null) {
      map['library_id'] = Variable<String>(libraryId);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    map['number'] = Variable<double>(number);
    map['item_count'] = Variable<int>(itemCount);
    map['page_count'] = Variable<int>(pageCount);
    map['modified'] = Variable<int>(modified);
    map['deleted'] = Variable<bool>(deleted);
    map['available'] = Variable<bool>(available);
    map['ordered'] = Variable<bool>(ordered);
    map['descriptive_metadata'] = Variable<String>(descriptiveMetadata);
    return map;
  }

  CatalogueEntriesCompanion toCompanion(bool nullToAbsent) {
    return CatalogueEntriesCompanion(
      accountId: Value(accountId),
      generation: Value(generation),
      kind: Value(kind),
      remoteId: Value(remoteId),
      title: Value(title),
      sortTitle: Value(sortTitle),
      summary: Value(summary),
      searchText: Value(searchText),
      libraryId: libraryId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      number: Value(number),
      itemCount: Value(itemCount),
      pageCount: Value(pageCount),
      modified: Value(modified),
      deleted: Value(deleted),
      available: Value(available),
      ordered: Value(ordered),
      descriptiveMetadata: Value(descriptiveMetadata),
    );
  }

  factory CatalogueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogueEntry(
      accountId: serializer.fromJson<String>(json['accountId']),
      generation: serializer.fromJson<String>(json['generation']),
      kind: serializer.fromJson<String>(json['kind']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      title: serializer.fromJson<String>(json['title']),
      sortTitle: serializer.fromJson<String>(json['sortTitle']),
      summary: serializer.fromJson<String>(json['summary']),
      searchText: serializer.fromJson<String>(json['searchText']),
      libraryId: serializer.fromJson<String?>(json['libraryId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      number: serializer.fromJson<double>(json['number']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      modified: serializer.fromJson<int>(json['modified']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      available: serializer.fromJson<bool>(json['available']),
      ordered: serializer.fromJson<bool>(json['ordered']),
      descriptiveMetadata: serializer.fromJson<String>(
        json['descriptiveMetadata'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'generation': serializer.toJson<String>(generation),
      'kind': serializer.toJson<String>(kind),
      'remoteId': serializer.toJson<String>(remoteId),
      'title': serializer.toJson<String>(title),
      'sortTitle': serializer.toJson<String>(sortTitle),
      'summary': serializer.toJson<String>(summary),
      'searchText': serializer.toJson<String>(searchText),
      'libraryId': serializer.toJson<String?>(libraryId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'number': serializer.toJson<double>(number),
      'itemCount': serializer.toJson<int>(itemCount),
      'pageCount': serializer.toJson<int>(pageCount),
      'modified': serializer.toJson<int>(modified),
      'deleted': serializer.toJson<bool>(deleted),
      'available': serializer.toJson<bool>(available),
      'ordered': serializer.toJson<bool>(ordered),
      'descriptiveMetadata': serializer.toJson<String>(descriptiveMetadata),
    };
  }

  CatalogueEntry copyWith({
    String? accountId,
    String? generation,
    String? kind,
    String? remoteId,
    String? title,
    String? sortTitle,
    String? summary,
    String? searchText,
    Value<String?> libraryId = const Value.absent(),
    Value<String?> seriesId = const Value.absent(),
    double? number,
    int? itemCount,
    int? pageCount,
    int? modified,
    bool? deleted,
    bool? available,
    bool? ordered,
    String? descriptiveMetadata,
  }) => CatalogueEntry(
    accountId: accountId ?? this.accountId,
    generation: generation ?? this.generation,
    kind: kind ?? this.kind,
    remoteId: remoteId ?? this.remoteId,
    title: title ?? this.title,
    sortTitle: sortTitle ?? this.sortTitle,
    summary: summary ?? this.summary,
    searchText: searchText ?? this.searchText,
    libraryId: libraryId.present ? libraryId.value : this.libraryId,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    number: number ?? this.number,
    itemCount: itemCount ?? this.itemCount,
    pageCount: pageCount ?? this.pageCount,
    modified: modified ?? this.modified,
    deleted: deleted ?? this.deleted,
    available: available ?? this.available,
    ordered: ordered ?? this.ordered,
    descriptiveMetadata: descriptiveMetadata ?? this.descriptiveMetadata,
  );
  CatalogueEntry copyWithCompanion(CatalogueEntriesCompanion data) {
    return CatalogueEntry(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      kind: data.kind.present ? data.kind.value : this.kind,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      title: data.title.present ? data.title.value : this.title,
      sortTitle: data.sortTitle.present ? data.sortTitle.value : this.sortTitle,
      summary: data.summary.present ? data.summary.value : this.summary,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      number: data.number.present ? data.number.value : this.number,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      modified: data.modified.present ? data.modified.value : this.modified,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      available: data.available.present ? data.available.value : this.available,
      ordered: data.ordered.present ? data.ordered.value : this.ordered,
      descriptiveMetadata: data.descriptiveMetadata.present
          ? data.descriptiveMetadata.value
          : this.descriptiveMetadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueEntry(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('kind: $kind, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('summary: $summary, ')
          ..write('searchText: $searchText, ')
          ..write('libraryId: $libraryId, ')
          ..write('seriesId: $seriesId, ')
          ..write('number: $number, ')
          ..write('itemCount: $itemCount, ')
          ..write('pageCount: $pageCount, ')
          ..write('modified: $modified, ')
          ..write('deleted: $deleted, ')
          ..write('available: $available, ')
          ..write('ordered: $ordered, ')
          ..write('descriptiveMetadata: $descriptiveMetadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    generation,
    kind,
    remoteId,
    title,
    sortTitle,
    summary,
    searchText,
    libraryId,
    seriesId,
    number,
    itemCount,
    pageCount,
    modified,
    deleted,
    available,
    ordered,
    descriptiveMetadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogueEntry &&
          other.accountId == this.accountId &&
          other.generation == this.generation &&
          other.kind == this.kind &&
          other.remoteId == this.remoteId &&
          other.title == this.title &&
          other.sortTitle == this.sortTitle &&
          other.summary == this.summary &&
          other.searchText == this.searchText &&
          other.libraryId == this.libraryId &&
          other.seriesId == this.seriesId &&
          other.number == this.number &&
          other.itemCount == this.itemCount &&
          other.pageCount == this.pageCount &&
          other.modified == this.modified &&
          other.deleted == this.deleted &&
          other.available == this.available &&
          other.ordered == this.ordered &&
          other.descriptiveMetadata == this.descriptiveMetadata);
}

class CatalogueEntriesCompanion extends UpdateCompanion<CatalogueEntry> {
  final Value<String> accountId;
  final Value<String> generation;
  final Value<String> kind;
  final Value<String> remoteId;
  final Value<String> title;
  final Value<String> sortTitle;
  final Value<String> summary;
  final Value<String> searchText;
  final Value<String?> libraryId;
  final Value<String?> seriesId;
  final Value<double> number;
  final Value<int> itemCount;
  final Value<int> pageCount;
  final Value<int> modified;
  final Value<bool> deleted;
  final Value<bool> available;
  final Value<bool> ordered;
  final Value<String> descriptiveMetadata;
  final Value<int> rowid;
  const CatalogueEntriesCompanion({
    this.accountId = const Value.absent(),
    this.generation = const Value.absent(),
    this.kind = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.sortTitle = const Value.absent(),
    this.summary = const Value.absent(),
    this.searchText = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.number = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.modified = const Value.absent(),
    this.deleted = const Value.absent(),
    this.available = const Value.absent(),
    this.ordered = const Value.absent(),
    this.descriptiveMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogueEntriesCompanion.insert({
    required String accountId,
    required String generation,
    required String kind,
    required String remoteId,
    required String title,
    required String sortTitle,
    required String summary,
    required String searchText,
    this.libraryId = const Value.absent(),
    this.seriesId = const Value.absent(),
    required double number,
    required int itemCount,
    required int pageCount,
    required int modified,
    required bool deleted,
    required bool available,
    required bool ordered,
    this.descriptiveMetadata = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       generation = Value(generation),
       kind = Value(kind),
       remoteId = Value(remoteId),
       title = Value(title),
       sortTitle = Value(sortTitle),
       summary = Value(summary),
       searchText = Value(searchText),
       number = Value(number),
       itemCount = Value(itemCount),
       pageCount = Value(pageCount),
       modified = Value(modified),
       deleted = Value(deleted),
       available = Value(available),
       ordered = Value(ordered);
  static Insertable<CatalogueEntry> custom({
    Expression<String>? accountId,
    Expression<String>? generation,
    Expression<String>? kind,
    Expression<String>? remoteId,
    Expression<String>? title,
    Expression<String>? sortTitle,
    Expression<String>? summary,
    Expression<String>? searchText,
    Expression<String>? libraryId,
    Expression<String>? seriesId,
    Expression<double>? number,
    Expression<int>? itemCount,
    Expression<int>? pageCount,
    Expression<int>? modified,
    Expression<bool>? deleted,
    Expression<bool>? available,
    Expression<bool>? ordered,
    Expression<String>? descriptiveMetadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (generation != null) 'generation': generation,
      if (kind != null) 'kind': kind,
      if (remoteId != null) 'remote_id': remoteId,
      if (title != null) 'title': title,
      if (sortTitle != null) 'sort_title': sortTitle,
      if (summary != null) 'summary': summary,
      if (searchText != null) 'search_text': searchText,
      if (libraryId != null) 'library_id': libraryId,
      if (seriesId != null) 'series_id': seriesId,
      if (number != null) 'number': number,
      if (itemCount != null) 'item_count': itemCount,
      if (pageCount != null) 'page_count': pageCount,
      if (modified != null) 'modified': modified,
      if (deleted != null) 'deleted': deleted,
      if (available != null) 'available': available,
      if (ordered != null) 'ordered': ordered,
      if (descriptiveMetadata != null)
        'descriptive_metadata': descriptiveMetadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogueEntriesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? generation,
    Value<String>? kind,
    Value<String>? remoteId,
    Value<String>? title,
    Value<String>? sortTitle,
    Value<String>? summary,
    Value<String>? searchText,
    Value<String?>? libraryId,
    Value<String?>? seriesId,
    Value<double>? number,
    Value<int>? itemCount,
    Value<int>? pageCount,
    Value<int>? modified,
    Value<bool>? deleted,
    Value<bool>? available,
    Value<bool>? ordered,
    Value<String>? descriptiveMetadata,
    Value<int>? rowid,
  }) {
    return CatalogueEntriesCompanion(
      accountId: accountId ?? this.accountId,
      generation: generation ?? this.generation,
      kind: kind ?? this.kind,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      sortTitle: sortTitle ?? this.sortTitle,
      summary: summary ?? this.summary,
      searchText: searchText ?? this.searchText,
      libraryId: libraryId ?? this.libraryId,
      seriesId: seriesId ?? this.seriesId,
      number: number ?? this.number,
      itemCount: itemCount ?? this.itemCount,
      pageCount: pageCount ?? this.pageCount,
      modified: modified ?? this.modified,
      deleted: deleted ?? this.deleted,
      available: available ?? this.available,
      ordered: ordered ?? this.ordered,
      descriptiveMetadata: descriptiveMetadata ?? this.descriptiveMetadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sortTitle.present) {
      map['sort_title'] = Variable<String>(sortTitle.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (number.present) {
      map['number'] = Variable<double>(number.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (modified.present) {
      map['modified'] = Variable<int>(modified.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (available.present) {
      map['available'] = Variable<bool>(available.value);
    }
    if (ordered.present) {
      map['ordered'] = Variable<bool>(ordered.value);
    }
    if (descriptiveMetadata.present) {
      map['descriptive_metadata'] = Variable<String>(descriptiveMetadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueEntriesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('kind: $kind, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('sortTitle: $sortTitle, ')
          ..write('summary: $summary, ')
          ..write('searchText: $searchText, ')
          ..write('libraryId: $libraryId, ')
          ..write('seriesId: $seriesId, ')
          ..write('number: $number, ')
          ..write('itemCount: $itemCount, ')
          ..write('pageCount: $pageCount, ')
          ..write('modified: $modified, ')
          ..write('deleted: $deleted, ')
          ..write('available: $available, ')
          ..write('ordered: $ordered, ')
          ..write('descriptiveMetadata: $descriptiveMetadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogueMembershipsTable extends CatalogueMemberships
    with TableInfo<$CatalogueMembershipsTable, CatalogueMembership> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogueMembershipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupKindMeta = const VerificationMeta(
    'groupKind',
  );
  @override
  late final GeneratedColumn<String> groupKind = GeneratedColumn<String>(
    'group_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemKindMeta = const VerificationMeta(
    'itemKind',
  );
  @override
  late final GeneratedColumn<String> itemKind = GeneratedColumn<String>(
    'item_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedMeta = const VerificationMeta(
    'removed',
  );
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
    'removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("removed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    generation,
    groupKind,
    groupId,
    itemKind,
    itemId,
    position,
    removed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalogue_memberships';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogueMembership> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('group_kind')) {
      context.handle(
        _groupKindMeta,
        groupKind.isAcceptableOrUnknown(data['group_kind']!, _groupKindMeta),
      );
    } else if (isInserting) {
      context.missing(_groupKindMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('item_kind')) {
      context.handle(
        _itemKindMeta,
        itemKind.isAcceptableOrUnknown(data['item_kind']!, _itemKindMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKindMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('removed')) {
      context.handle(
        _removedMeta,
        removed.isAcceptableOrUnknown(data['removed']!, _removedMeta),
      );
    } else if (isInserting) {
      context.missing(_removedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountId,
    generation,
    groupKind,
    groupId,
    itemId,
  };
  @override
  CatalogueMembership map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogueMembership(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation'],
      )!,
      groupKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_kind'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      itemKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_kind'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      removed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}removed'],
      )!,
    );
  }

  @override
  $CatalogueMembershipsTable createAlias(String alias) {
    return $CatalogueMembershipsTable(attachedDatabase, alias);
  }
}

class CatalogueMembership extends DataClass
    implements Insertable<CatalogueMembership> {
  final String accountId;
  final String generation;
  final String groupKind;
  final String groupId;
  final String itemKind;
  final String itemId;
  final int position;
  final bool removed;
  const CatalogueMembership({
    required this.accountId,
    required this.generation,
    required this.groupKind,
    required this.groupId,
    required this.itemKind,
    required this.itemId,
    required this.position,
    required this.removed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['generation'] = Variable<String>(generation);
    map['group_kind'] = Variable<String>(groupKind);
    map['group_id'] = Variable<String>(groupId);
    map['item_kind'] = Variable<String>(itemKind);
    map['item_id'] = Variable<String>(itemId);
    map['position'] = Variable<int>(position);
    map['removed'] = Variable<bool>(removed);
    return map;
  }

  CatalogueMembershipsCompanion toCompanion(bool nullToAbsent) {
    return CatalogueMembershipsCompanion(
      accountId: Value(accountId),
      generation: Value(generation),
      groupKind: Value(groupKind),
      groupId: Value(groupId),
      itemKind: Value(itemKind),
      itemId: Value(itemId),
      position: Value(position),
      removed: Value(removed),
    );
  }

  factory CatalogueMembership.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogueMembership(
      accountId: serializer.fromJson<String>(json['accountId']),
      generation: serializer.fromJson<String>(json['generation']),
      groupKind: serializer.fromJson<String>(json['groupKind']),
      groupId: serializer.fromJson<String>(json['groupId']),
      itemKind: serializer.fromJson<String>(json['itemKind']),
      itemId: serializer.fromJson<String>(json['itemId']),
      position: serializer.fromJson<int>(json['position']),
      removed: serializer.fromJson<bool>(json['removed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'generation': serializer.toJson<String>(generation),
      'groupKind': serializer.toJson<String>(groupKind),
      'groupId': serializer.toJson<String>(groupId),
      'itemKind': serializer.toJson<String>(itemKind),
      'itemId': serializer.toJson<String>(itemId),
      'position': serializer.toJson<int>(position),
      'removed': serializer.toJson<bool>(removed),
    };
  }

  CatalogueMembership copyWith({
    String? accountId,
    String? generation,
    String? groupKind,
    String? groupId,
    String? itemKind,
    String? itemId,
    int? position,
    bool? removed,
  }) => CatalogueMembership(
    accountId: accountId ?? this.accountId,
    generation: generation ?? this.generation,
    groupKind: groupKind ?? this.groupKind,
    groupId: groupId ?? this.groupId,
    itemKind: itemKind ?? this.itemKind,
    itemId: itemId ?? this.itemId,
    position: position ?? this.position,
    removed: removed ?? this.removed,
  );
  CatalogueMembership copyWithCompanion(CatalogueMembershipsCompanion data) {
    return CatalogueMembership(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      groupKind: data.groupKind.present ? data.groupKind.value : this.groupKind,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      itemKind: data.itemKind.present ? data.itemKind.value : this.itemKind,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
      removed: data.removed.present ? data.removed.value : this.removed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueMembership(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('groupKind: $groupKind, ')
          ..write('groupId: $groupId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('removed: $removed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    generation,
    groupKind,
    groupId,
    itemKind,
    itemId,
    position,
    removed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogueMembership &&
          other.accountId == this.accountId &&
          other.generation == this.generation &&
          other.groupKind == this.groupKind &&
          other.groupId == this.groupId &&
          other.itemKind == this.itemKind &&
          other.itemId == this.itemId &&
          other.position == this.position &&
          other.removed == this.removed);
}

class CatalogueMembershipsCompanion
    extends UpdateCompanion<CatalogueMembership> {
  final Value<String> accountId;
  final Value<String> generation;
  final Value<String> groupKind;
  final Value<String> groupId;
  final Value<String> itemKind;
  final Value<String> itemId;
  final Value<int> position;
  final Value<bool> removed;
  final Value<int> rowid;
  const CatalogueMembershipsCompanion({
    this.accountId = const Value.absent(),
    this.generation = const Value.absent(),
    this.groupKind = const Value.absent(),
    this.groupId = const Value.absent(),
    this.itemKind = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.removed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogueMembershipsCompanion.insert({
    required String accountId,
    required String generation,
    required String groupKind,
    required String groupId,
    required String itemKind,
    required String itemId,
    required int position,
    required bool removed,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       generation = Value(generation),
       groupKind = Value(groupKind),
       groupId = Value(groupId),
       itemKind = Value(itemKind),
       itemId = Value(itemId),
       position = Value(position),
       removed = Value(removed);
  static Insertable<CatalogueMembership> custom({
    Expression<String>? accountId,
    Expression<String>? generation,
    Expression<String>? groupKind,
    Expression<String>? groupId,
    Expression<String>? itemKind,
    Expression<String>? itemId,
    Expression<int>? position,
    Expression<bool>? removed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (generation != null) 'generation': generation,
      if (groupKind != null) 'group_kind': groupKind,
      if (groupId != null) 'group_id': groupId,
      if (itemKind != null) 'item_kind': itemKind,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
      if (removed != null) 'removed': removed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogueMembershipsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? generation,
    Value<String>? groupKind,
    Value<String>? groupId,
    Value<String>? itemKind,
    Value<String>? itemId,
    Value<int>? position,
    Value<bool>? removed,
    Value<int>? rowid,
  }) {
    return CatalogueMembershipsCompanion(
      accountId: accountId ?? this.accountId,
      generation: generation ?? this.generation,
      groupKind: groupKind ?? this.groupKind,
      groupId: groupId ?? this.groupId,
      itemKind: itemKind ?? this.itemKind,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      removed: removed ?? this.removed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (groupKind.present) {
      map['group_kind'] = Variable<String>(groupKind.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (itemKind.present) {
      map['item_kind'] = Variable<String>(itemKind.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueMembershipsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('groupKind: $groupKind, ')
          ..write('groupId: $groupId, ')
          ..write('itemKind: $itemKind, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('removed: $removed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogueSnapshotsTable extends CatalogueSnapshots
    with TableInfo<$CatalogueSnapshotsTable, CatalogueSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogueSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, generation, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalogue_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogueSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  CatalogueSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogueSnapshot(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatalogueSnapshotsTable createAlias(String alias) {
    return $CatalogueSnapshotsTable(attachedDatabase, alias);
  }
}

class CatalogueSnapshot extends DataClass
    implements Insertable<CatalogueSnapshot> {
  final String accountId;
  final String generation;
  final DateTime updatedAt;
  const CatalogueSnapshot({
    required this.accountId,
    required this.generation,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['generation'] = Variable<String>(generation);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogueSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return CatalogueSnapshotsCompanion(
      accountId: Value(accountId),
      generation: Value(generation),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatalogueSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogueSnapshot(
      accountId: serializer.fromJson<String>(json['accountId']),
      generation: serializer.fromJson<String>(json['generation']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'generation': serializer.toJson<String>(generation),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatalogueSnapshot copyWith({
    String? accountId,
    String? generation,
    DateTime? updatedAt,
  }) => CatalogueSnapshot(
    accountId: accountId ?? this.accountId,
    generation: generation ?? this.generation,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatalogueSnapshot copyWithCompanion(CatalogueSnapshotsCompanion data) {
    return CatalogueSnapshot(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueSnapshot(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, generation, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogueSnapshot &&
          other.accountId == this.accountId &&
          other.generation == this.generation &&
          other.updatedAt == this.updatedAt);
}

class CatalogueSnapshotsCompanion extends UpdateCompanion<CatalogueSnapshot> {
  final Value<String> accountId;
  final Value<String> generation;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatalogueSnapshotsCompanion({
    this.accountId = const Value.absent(),
    this.generation = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogueSnapshotsCompanion.insert({
    required String accountId,
    required String generation,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       generation = Value(generation),
       updatedAt = Value(updatedAt);
  static Insertable<CatalogueSnapshot> custom({
    Expression<String>? accountId,
    Expression<String>? generation,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (generation != null) 'generation': generation,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogueSnapshotsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? generation,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatalogueSnapshotsCompanion(
      accountId: accountId ?? this.accountId,
      generation: generation ?? this.generation,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogueSnapshotsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('generation: $generation, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReaderManifestsTable extends ReaderManifests
    with TableInfo<$ReaderManifestsTable, StoredReaderManifest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, bookId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReaderManifest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, bookId};
  @override
  StoredReaderManifest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReaderManifest(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ReaderManifestsTable createAlias(String alias) {
    return $ReaderManifestsTable(attachedDatabase, alias);
  }
}

class StoredReaderManifest extends DataClass
    implements Insertable<StoredReaderManifest> {
  final String accountId;
  final String bookId;
  final String payload;
  const StoredReaderManifest({
    required this.accountId,
    required this.bookId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ReaderManifestsCompanion toCompanion(bool nullToAbsent) {
    return ReaderManifestsCompanion(
      accountId: Value(accountId),
      bookId: Value(bookId),
      payload: Value(payload),
    );
  }

  factory StoredReaderManifest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReaderManifest(
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  StoredReaderManifest copyWith({
    String? accountId,
    String? bookId,
    String? payload,
  }) => StoredReaderManifest(
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    payload: payload ?? this.payload,
  );
  StoredReaderManifest copyWithCompanion(ReaderManifestsCompanion data) {
    return StoredReaderManifest(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReaderManifest(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, bookId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReaderManifest &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.payload == this.payload);
}

class ReaderManifestsCompanion extends UpdateCompanion<StoredReaderManifest> {
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<String> payload;
  final Value<int> rowid;
  const ReaderManifestsCompanion({
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderManifestsCompanion.insert({
    required String accountId,
    required String bookId,
    required String payload,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       bookId = Value(bookId),
       payload = Value(payload);
  static Insertable<StoredReaderManifest> custom({
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderManifestsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? bookId,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ReaderManifestsCompanion(
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderManifestsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReaderAssetsTable extends ReaderAssets
    with TableInfo<$ReaderAssetsTable, ReaderAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<String> tier = GeneratedColumn<String>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _representationMeta = const VerificationMeta(
    'representation',
  );
  @override
  late final GeneratedColumn<String> representation = GeneratedColumn<String>(
    'representation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessMeta = const VerificationMeta(
    'lastAccess',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccess = GeneratedColumn<DateTime>(
    'last_access',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    tier,
    accountId,
    bookId,
    revision,
    pageIndex,
    representation,
    checksum,
    mediaType,
    byteLength,
    lastAccess,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderAsset> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('representation')) {
      context.handle(
        _representationMeta,
        representation.isAcceptableOrUnknown(
          data['representation']!,
          _representationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_representationMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    if (data.containsKey('last_access')) {
      context.handle(
        _lastAccessMeta,
        lastAccess.isAcceptableOrUnknown(data['last_access']!, _lastAccessMeta),
      );
    } else if (isInserting) {
      context.missing(_lastAccessMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId, tier};
  @override
  ReaderAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderAsset(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tier'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      representation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}representation'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
      lastAccess: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_access'],
      )!,
    );
  }

  @override
  $ReaderAssetsTable createAlias(String alias) {
    return $ReaderAssetsTable(attachedDatabase, alias);
  }
}

class ReaderAsset extends DataClass implements Insertable<ReaderAsset> {
  final String assetId;
  final String tier;
  final String accountId;
  final String bookId;
  final String revision;
  final int pageIndex;
  final String representation;
  final String checksum;
  final String mediaType;
  final int byteLength;
  final DateTime lastAccess;
  const ReaderAsset({
    required this.assetId,
    required this.tier,
    required this.accountId,
    required this.bookId,
    required this.revision,
    required this.pageIndex,
    required this.representation,
    required this.checksum,
    required this.mediaType,
    required this.byteLength,
    required this.lastAccess,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['tier'] = Variable<String>(tier);
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['revision'] = Variable<String>(revision);
    map['page_index'] = Variable<int>(pageIndex);
    map['representation'] = Variable<String>(representation);
    map['checksum'] = Variable<String>(checksum);
    map['media_type'] = Variable<String>(mediaType);
    map['byte_length'] = Variable<int>(byteLength);
    map['last_access'] = Variable<DateTime>(lastAccess);
    return map;
  }

  ReaderAssetsCompanion toCompanion(bool nullToAbsent) {
    return ReaderAssetsCompanion(
      assetId: Value(assetId),
      tier: Value(tier),
      accountId: Value(accountId),
      bookId: Value(bookId),
      revision: Value(revision),
      pageIndex: Value(pageIndex),
      representation: Value(representation),
      checksum: Value(checksum),
      mediaType: Value(mediaType),
      byteLength: Value(byteLength),
      lastAccess: Value(lastAccess),
    );
  }

  factory ReaderAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderAsset(
      assetId: serializer.fromJson<String>(json['assetId']),
      tier: serializer.fromJson<String>(json['tier']),
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      revision: serializer.fromJson<String>(json['revision']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      representation: serializer.fromJson<String>(json['representation']),
      checksum: serializer.fromJson<String>(json['checksum']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
      lastAccess: serializer.fromJson<DateTime>(json['lastAccess']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'tier': serializer.toJson<String>(tier),
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'revision': serializer.toJson<String>(revision),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'representation': serializer.toJson<String>(representation),
      'checksum': serializer.toJson<String>(checksum),
      'mediaType': serializer.toJson<String>(mediaType),
      'byteLength': serializer.toJson<int>(byteLength),
      'lastAccess': serializer.toJson<DateTime>(lastAccess),
    };
  }

  ReaderAsset copyWith({
    String? assetId,
    String? tier,
    String? accountId,
    String? bookId,
    String? revision,
    int? pageIndex,
    String? representation,
    String? checksum,
    String? mediaType,
    int? byteLength,
    DateTime? lastAccess,
  }) => ReaderAsset(
    assetId: assetId ?? this.assetId,
    tier: tier ?? this.tier,
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    revision: revision ?? this.revision,
    pageIndex: pageIndex ?? this.pageIndex,
    representation: representation ?? this.representation,
    checksum: checksum ?? this.checksum,
    mediaType: mediaType ?? this.mediaType,
    byteLength: byteLength ?? this.byteLength,
    lastAccess: lastAccess ?? this.lastAccess,
  );
  ReaderAsset copyWithCompanion(ReaderAssetsCompanion data) {
    return ReaderAsset(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      tier: data.tier.present ? data.tier.value : this.tier,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      revision: data.revision.present ? data.revision.value : this.revision,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      representation: data.representation.present
          ? data.representation.value
          : this.representation,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      lastAccess: data.lastAccess.present
          ? data.lastAccess.value
          : this.lastAccess,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderAsset(')
          ..write('assetId: $assetId, ')
          ..write('tier: $tier, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('representation: $representation, ')
          ..write('checksum: $checksum, ')
          ..write('mediaType: $mediaType, ')
          ..write('byteLength: $byteLength, ')
          ..write('lastAccess: $lastAccess')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    assetId,
    tier,
    accountId,
    bookId,
    revision,
    pageIndex,
    representation,
    checksum,
    mediaType,
    byteLength,
    lastAccess,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderAsset &&
          other.assetId == this.assetId &&
          other.tier == this.tier &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.revision == this.revision &&
          other.pageIndex == this.pageIndex &&
          other.representation == this.representation &&
          other.checksum == this.checksum &&
          other.mediaType == this.mediaType &&
          other.byteLength == this.byteLength &&
          other.lastAccess == this.lastAccess);
}

class ReaderAssetsCompanion extends UpdateCompanion<ReaderAsset> {
  final Value<String> assetId;
  final Value<String> tier;
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<String> revision;
  final Value<int> pageIndex;
  final Value<String> representation;
  final Value<String> checksum;
  final Value<String> mediaType;
  final Value<int> byteLength;
  final Value<DateTime> lastAccess;
  final Value<int> rowid;
  const ReaderAssetsCompanion({
    this.assetId = const Value.absent(),
    this.tier = const Value.absent(),
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.revision = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.representation = const Value.absent(),
    this.checksum = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.lastAccess = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderAssetsCompanion.insert({
    required String assetId,
    required String tier,
    required String accountId,
    required String bookId,
    required String revision,
    required int pageIndex,
    required String representation,
    required String checksum,
    required String mediaType,
    required int byteLength,
    required DateTime lastAccess,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       tier = Value(tier),
       accountId = Value(accountId),
       bookId = Value(bookId),
       revision = Value(revision),
       pageIndex = Value(pageIndex),
       representation = Value(representation),
       checksum = Value(checksum),
       mediaType = Value(mediaType),
       byteLength = Value(byteLength),
       lastAccess = Value(lastAccess);
  static Insertable<ReaderAsset> custom({
    Expression<String>? assetId,
    Expression<String>? tier,
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<String>? revision,
    Expression<int>? pageIndex,
    Expression<String>? representation,
    Expression<String>? checksum,
    Expression<String>? mediaType,
    Expression<int>? byteLength,
    Expression<DateTime>? lastAccess,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (tier != null) 'tier': tier,
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (revision != null) 'revision': revision,
      if (pageIndex != null) 'page_index': pageIndex,
      if (representation != null) 'representation': representation,
      if (checksum != null) 'checksum': checksum,
      if (mediaType != null) 'media_type': mediaType,
      if (byteLength != null) 'byte_length': byteLength,
      if (lastAccess != null) 'last_access': lastAccess,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderAssetsCompanion copyWith({
    Value<String>? assetId,
    Value<String>? tier,
    Value<String>? accountId,
    Value<String>? bookId,
    Value<String>? revision,
    Value<int>? pageIndex,
    Value<String>? representation,
    Value<String>? checksum,
    Value<String>? mediaType,
    Value<int>? byteLength,
    Value<DateTime>? lastAccess,
    Value<int>? rowid,
  }) {
    return ReaderAssetsCompanion(
      assetId: assetId ?? this.assetId,
      tier: tier ?? this.tier,
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      revision: revision ?? this.revision,
      pageIndex: pageIndex ?? this.pageIndex,
      representation: representation ?? this.representation,
      checksum: checksum ?? this.checksum,
      mediaType: mediaType ?? this.mediaType,
      byteLength: byteLength ?? this.byteLength,
      lastAccess: lastAccess ?? this.lastAccess,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (tier.present) {
      map['tier'] = Variable<String>(tier.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (representation.present) {
      map['representation'] = Variable<String>(representation.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (lastAccess.present) {
      map['last_access'] = Variable<DateTime>(lastAccess.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderAssetsCompanion(')
          ..write('assetId: $assetId, ')
          ..write('tier: $tier, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('representation: $representation, ')
          ..write('checksum: $checksum, ')
          ..write('mediaType: $mediaType, ')
          ..write('byteLength: $byteLength, ')
          ..write('lastAccess: $lastAccess, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReaderDownloadsTable extends ReaderDownloads
    with TableInfo<$ReaderDownloadsTable, ReaderDownload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderDownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, bookId, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderDownload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, bookId, revision};
  @override
  ReaderDownload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderDownload(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $ReaderDownloadsTable createAlias(String alias) {
    return $ReaderDownloadsTable(attachedDatabase, alias);
  }
}

class ReaderDownload extends DataClass implements Insertable<ReaderDownload> {
  final String accountId;
  final String bookId;
  final String revision;
  const ReaderDownload({
    required this.accountId,
    required this.bookId,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['revision'] = Variable<String>(revision);
    return map;
  }

  ReaderDownloadsCompanion toCompanion(bool nullToAbsent) {
    return ReaderDownloadsCompanion(
      accountId: Value(accountId),
      bookId: Value(bookId),
      revision: Value(revision),
    );
  }

  factory ReaderDownload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderDownload(
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      revision: serializer.fromJson<String>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'revision': serializer.toJson<String>(revision),
    };
  }

  ReaderDownload copyWith({
    String? accountId,
    String? bookId,
    String? revision,
  }) => ReaderDownload(
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    revision: revision ?? this.revision,
  );
  ReaderDownload copyWithCompanion(ReaderDownloadsCompanion data) {
    return ReaderDownload(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderDownload(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, bookId, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderDownload &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.revision == this.revision);
}

class ReaderDownloadsCompanion extends UpdateCompanion<ReaderDownload> {
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<String> revision;
  final Value<int> rowid;
  const ReaderDownloadsCompanion({
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderDownloadsCompanion.insert({
    required String accountId,
    required String bookId,
    required String revision,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       bookId = Value(bookId),
       revision = Value(revision);
  static Insertable<ReaderDownload> custom({
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<String>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderDownloadsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? bookId,
    Value<String>? revision,
    Value<int>? rowid,
  }) {
    return ReaderDownloadsCompanion(
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderDownloadsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingPreferencesTable extends ReadingPreferences
    with TableInfo<$ReadingPreferencesTable, ReadingPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, scope, scopeId, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, scope, scopeId};
  @override
  ReadingPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingPreference(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ReadingPreferencesTable createAlias(String alias) {
    return $ReadingPreferencesTable(attachedDatabase, alias);
  }
}

class ReadingPreference extends DataClass
    implements Insertable<ReadingPreference> {
  final String accountId;
  final String scope;
  final String scopeId;
  final String payload;
  const ReadingPreference({
    required this.accountId,
    required this.scope,
    required this.scopeId,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['scope'] = Variable<String>(scope);
    map['scope_id'] = Variable<String>(scopeId);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ReadingPreferencesCompanion toCompanion(bool nullToAbsent) {
    return ReadingPreferencesCompanion(
      accountId: Value(accountId),
      scope: Value(scope),
      scopeId: Value(scopeId),
      payload: Value(payload),
    );
  }

  factory ReadingPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingPreference(
      accountId: serializer.fromJson<String>(json['accountId']),
      scope: serializer.fromJson<String>(json['scope']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'scope': serializer.toJson<String>(scope),
      'scopeId': serializer.toJson<String>(scopeId),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ReadingPreference copyWith({
    String? accountId,
    String? scope,
    String? scopeId,
    String? payload,
  }) => ReadingPreference(
    accountId: accountId ?? this.accountId,
    scope: scope ?? this.scope,
    scopeId: scopeId ?? this.scopeId,
    payload: payload ?? this.payload,
  );
  ReadingPreference copyWithCompanion(ReadingPreferencesCompanion data) {
    return ReadingPreference(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      scope: data.scope.present ? data.scope.value : this.scope,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPreference(')
          ..write('accountId: $accountId, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, scope, scopeId, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingPreference &&
          other.accountId == this.accountId &&
          other.scope == this.scope &&
          other.scopeId == this.scopeId &&
          other.payload == this.payload);
}

class ReadingPreferencesCompanion extends UpdateCompanion<ReadingPreference> {
  final Value<String> accountId;
  final Value<String> scope;
  final Value<String> scopeId;
  final Value<String> payload;
  final Value<int> rowid;
  const ReadingPreferencesCompanion({
    this.accountId = const Value.absent(),
    this.scope = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingPreferencesCompanion.insert({
    required String accountId,
    required String scope,
    required String scopeId,
    required String payload,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       scope = Value(scope),
       scopeId = Value(scopeId),
       payload = Value(payload);
  static Insertable<ReadingPreference> custom({
    Expression<String>? accountId,
    Expression<String>? scope,
    Expression<String>? scopeId,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (scope != null) 'scope': scope,
      if (scopeId != null) 'scope_id': scopeId,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingPreferencesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? scope,
    Value<String>? scopeId,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ReadingPreferencesCompanion(
      accountId: accountId ?? this.accountId,
      scope: scope ?? this.scope,
      scopeId: scopeId ?? this.scopeId,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingPreferencesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('scope: $scope, ')
          ..write('scopeId: $scopeId, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReaderPositionsTable extends ReaderPositions
    with TableInfo<$ReaderPositionsTable, ReaderPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentLocatorMeta = const VerificationMeta(
    'documentLocator',
  );
  @override
  late final GeneratedColumn<String> documentLocator = GeneratedColumn<String>(
    'document_locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fractionMeta = const VerificationMeta(
    'fraction',
  );
  @override
  late final GeneratedColumn<double> fraction = GeneratedColumn<double>(
    'fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentLocator,
    accountId,
    bookId,
    revision,
    pageIndex,
    fraction,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderPosition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_locator')) {
      context.handle(
        _documentLocatorMeta,
        documentLocator.isAcceptableOrUnknown(
          data['document_locator']!,
          _documentLocatorMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('fraction')) {
      context.handle(
        _fractionMeta,
        fraction.isAcceptableOrUnknown(data['fraction']!, _fractionMeta),
      );
    } else if (isInserting) {
      context.missing(_fractionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, bookId};
  @override
  ReaderPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderPosition(
      documentLocator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_locator'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      fraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fraction'],
      )!,
    );
  }

  @override
  $ReaderPositionsTable createAlias(String alias) {
    return $ReaderPositionsTable(attachedDatabase, alias);
  }
}

class ReaderPosition extends DataClass implements Insertable<ReaderPosition> {
  final String? documentLocator;
  final String accountId;
  final String bookId;
  final String revision;
  final int pageIndex;
  final double fraction;
  const ReaderPosition({
    this.documentLocator,
    required this.accountId,
    required this.bookId,
    required this.revision,
    required this.pageIndex,
    required this.fraction,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || documentLocator != null) {
      map['document_locator'] = Variable<String>(documentLocator);
    }
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['revision'] = Variable<String>(revision);
    map['page_index'] = Variable<int>(pageIndex);
    map['fraction'] = Variable<double>(fraction);
    return map;
  }

  ReaderPositionsCompanion toCompanion(bool nullToAbsent) {
    return ReaderPositionsCompanion(
      documentLocator: documentLocator == null && nullToAbsent
          ? const Value.absent()
          : Value(documentLocator),
      accountId: Value(accountId),
      bookId: Value(bookId),
      revision: Value(revision),
      pageIndex: Value(pageIndex),
      fraction: Value(fraction),
    );
  }

  factory ReaderPosition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderPosition(
      documentLocator: serializer.fromJson<String?>(json['documentLocator']),
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      revision: serializer.fromJson<String>(json['revision']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      fraction: serializer.fromJson<double>(json['fraction']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentLocator': serializer.toJson<String?>(documentLocator),
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'revision': serializer.toJson<String>(revision),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'fraction': serializer.toJson<double>(fraction),
    };
  }

  ReaderPosition copyWith({
    Value<String?> documentLocator = const Value.absent(),
    String? accountId,
    String? bookId,
    String? revision,
    int? pageIndex,
    double? fraction,
  }) => ReaderPosition(
    documentLocator: documentLocator.present
        ? documentLocator.value
        : this.documentLocator,
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    revision: revision ?? this.revision,
    pageIndex: pageIndex ?? this.pageIndex,
    fraction: fraction ?? this.fraction,
  );
  ReaderPosition copyWithCompanion(ReaderPositionsCompanion data) {
    return ReaderPosition(
      documentLocator: data.documentLocator.present
          ? data.documentLocator.value
          : this.documentLocator,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      revision: data.revision.present ? data.revision.value : this.revision,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      fraction: data.fraction.present ? data.fraction.value : this.fraction,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderPosition(')
          ..write('documentLocator: $documentLocator, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('fraction: $fraction')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentLocator,
    accountId,
    bookId,
    revision,
    pageIndex,
    fraction,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderPosition &&
          other.documentLocator == this.documentLocator &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.revision == this.revision &&
          other.pageIndex == this.pageIndex &&
          other.fraction == this.fraction);
}

class ReaderPositionsCompanion extends UpdateCompanion<ReaderPosition> {
  final Value<String?> documentLocator;
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<String> revision;
  final Value<int> pageIndex;
  final Value<double> fraction;
  final Value<int> rowid;
  const ReaderPositionsCompanion({
    this.documentLocator = const Value.absent(),
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.revision = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.fraction = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderPositionsCompanion.insert({
    this.documentLocator = const Value.absent(),
    required String accountId,
    required String bookId,
    required String revision,
    required int pageIndex,
    required double fraction,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       bookId = Value(bookId),
       revision = Value(revision),
       pageIndex = Value(pageIndex),
       fraction = Value(fraction);
  static Insertable<ReaderPosition> custom({
    Expression<String>? documentLocator,
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<String>? revision,
    Expression<int>? pageIndex,
    Expression<double>? fraction,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentLocator != null) 'document_locator': documentLocator,
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (revision != null) 'revision': revision,
      if (pageIndex != null) 'page_index': pageIndex,
      if (fraction != null) 'fraction': fraction,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderPositionsCompanion copyWith({
    Value<String?>? documentLocator,
    Value<String>? accountId,
    Value<String>? bookId,
    Value<String>? revision,
    Value<int>? pageIndex,
    Value<double>? fraction,
    Value<int>? rowid,
  }) {
    return ReaderPositionsCompanion(
      documentLocator: documentLocator ?? this.documentLocator,
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      revision: revision ?? this.revision,
      pageIndex: pageIndex ?? this.pageIndex,
      fraction: fraction ?? this.fraction,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentLocator.present) {
      map['document_locator'] = Variable<String>(documentLocator.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (fraction.present) {
      map['fraction'] = Variable<double>(fraction.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderPositionsCompanion(')
          ..write('documentLocator: $documentLocator, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('fraction: $fraction, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineSettingsTable extends OfflineSettings
    with TableInfo<$OfflineSettingsTable, OfflineSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quotaMeta = const VerificationMeta('quota');
  @override
  late final GeneratedColumn<int> quota = GeneratedColumn<int>(
    'quota',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wifiOnlyMeta = const VerificationMeta(
    'wifiOnly',
  );
  @override
  late final GeneratedColumn<bool> wifiOnly = GeneratedColumn<bool>(
    'wifi_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wifi_only" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, quota, wifiOnly];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('quota')) {
      context.handle(
        _quotaMeta,
        quota.isAcceptableOrUnknown(data['quota']!, _quotaMeta),
      );
    } else if (isInserting) {
      context.missing(_quotaMeta);
    }
    if (data.containsKey('wifi_only')) {
      context.handle(
        _wifiOnlyMeta,
        wifiOnly.isAcceptableOrUnknown(data['wifi_only']!, _wifiOnlyMeta),
      );
    } else if (isInserting) {
      context.missing(_wifiOnlyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  OfflineSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineSetting(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      quota: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quota'],
      )!,
      wifiOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wifi_only'],
      )!,
    );
  }

  @override
  $OfflineSettingsTable createAlias(String alias) {
    return $OfflineSettingsTable(attachedDatabase, alias);
  }
}

class OfflineSetting extends DataClass implements Insertable<OfflineSetting> {
  final String accountId;
  final int quota;
  final bool wifiOnly;
  const OfflineSetting({
    required this.accountId,
    required this.quota,
    required this.wifiOnly,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['quota'] = Variable<int>(quota);
    map['wifi_only'] = Variable<bool>(wifiOnly);
    return map;
  }

  OfflineSettingsCompanion toCompanion(bool nullToAbsent) {
    return OfflineSettingsCompanion(
      accountId: Value(accountId),
      quota: Value(quota),
      wifiOnly: Value(wifiOnly),
    );
  }

  factory OfflineSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineSetting(
      accountId: serializer.fromJson<String>(json['accountId']),
      quota: serializer.fromJson<int>(json['quota']),
      wifiOnly: serializer.fromJson<bool>(json['wifiOnly']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'quota': serializer.toJson<int>(quota),
      'wifiOnly': serializer.toJson<bool>(wifiOnly),
    };
  }

  OfflineSetting copyWith({String? accountId, int? quota, bool? wifiOnly}) =>
      OfflineSetting(
        accountId: accountId ?? this.accountId,
        quota: quota ?? this.quota,
        wifiOnly: wifiOnly ?? this.wifiOnly,
      );
  OfflineSetting copyWithCompanion(OfflineSettingsCompanion data) {
    return OfflineSetting(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      quota: data.quota.present ? data.quota.value : this.quota,
      wifiOnly: data.wifiOnly.present ? data.wifiOnly.value : this.wifiOnly,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSetting(')
          ..write('accountId: $accountId, ')
          ..write('quota: $quota, ')
          ..write('wifiOnly: $wifiOnly')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, quota, wifiOnly);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineSetting &&
          other.accountId == this.accountId &&
          other.quota == this.quota &&
          other.wifiOnly == this.wifiOnly);
}

class OfflineSettingsCompanion extends UpdateCompanion<OfflineSetting> {
  final Value<String> accountId;
  final Value<int> quota;
  final Value<bool> wifiOnly;
  final Value<int> rowid;
  const OfflineSettingsCompanion({
    this.accountId = const Value.absent(),
    this.quota = const Value.absent(),
    this.wifiOnly = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineSettingsCompanion.insert({
    required String accountId,
    required int quota,
    required bool wifiOnly,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       quota = Value(quota),
       wifiOnly = Value(wifiOnly);
  static Insertable<OfflineSetting> custom({
    Expression<String>? accountId,
    Expression<int>? quota,
    Expression<bool>? wifiOnly,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (quota != null) 'quota': quota,
      if (wifiOnly != null) 'wifi_only': wifiOnly,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineSettingsCompanion copyWith({
    Value<String>? accountId,
    Value<int>? quota,
    Value<bool>? wifiOnly,
    Value<int>? rowid,
  }) {
    return OfflineSettingsCompanion(
      accountId: accountId ?? this.accountId,
      quota: quota ?? this.quota,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (quota.present) {
      map['quota'] = Variable<int>(quota.value);
    }
    if (wifiOnly.present) {
      map['wifi_only'] = Variable<bool>(wifiOnly.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineSettingsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('quota: $quota, ')
          ..write('wifiOnly: $wifiOnly, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadJobsTable extends DownloadJobs
    with TableInfo<$DownloadJobsTable, DownloadJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestMeta = const VerificationMeta(
    'manifest',
  );
  @override
  late final GeneratedColumn<String> manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reservedBytesMeta = const VerificationMeta(
    'reservedBytes',
  );
  @override
  late final GeneratedColumn<int> reservedBytes = GeneratedColumn<int>(
    'reserved_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retryAtMeta = const VerificationMeta(
    'retryAt',
  );
  @override
  late final GeneratedColumn<int> retryAt = GeneratedColumn<int>(
    'retry_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    bookId,
    revision,
    manifest,
    state,
    reservedBytes,
    attempt,
    retryAt,
    error,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('manifest')) {
      context.handle(
        _manifestMeta,
        manifest.isAcceptableOrUnknown(data['manifest']!, _manifestMeta),
      );
    } else if (isInserting) {
      context.missing(_manifestMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('reserved_bytes')) {
      context.handle(
        _reservedBytesMeta,
        reservedBytes.isAcceptableOrUnknown(
          data['reserved_bytes']!,
          _reservedBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reservedBytesMeta);
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('retry_at')) {
      context.handle(
        _retryAtMeta,
        retryAt.isAcceptableOrUnknown(data['retry_at']!, _retryAtMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      manifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      reservedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reserved_bytes'],
      )!,
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      retryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_at'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
    );
  }

  @override
  $DownloadJobsTable createAlias(String alias) {
    return $DownloadJobsTable(attachedDatabase, alias);
  }
}

class DownloadJob extends DataClass implements Insertable<DownloadJob> {
  final String id;
  final String accountId;
  final String bookId;
  final String revision;
  final String manifest;
  final String state;
  final int reservedBytes;
  final int attempt;
  final int retryAt;
  final String? error;
  const DownloadJob({
    required this.id,
    required this.accountId,
    required this.bookId,
    required this.revision,
    required this.manifest,
    required this.state,
    required this.reservedBytes,
    required this.attempt,
    required this.retryAt,
    this.error,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['revision'] = Variable<String>(revision);
    map['manifest'] = Variable<String>(manifest);
    map['state'] = Variable<String>(state);
    map['reserved_bytes'] = Variable<int>(reservedBytes);
    map['attempt'] = Variable<int>(attempt);
    map['retry_at'] = Variable<int>(retryAt);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    return map;
  }

  DownloadJobsCompanion toCompanion(bool nullToAbsent) {
    return DownloadJobsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      bookId: Value(bookId),
      revision: Value(revision),
      manifest: Value(manifest),
      state: Value(state),
      reservedBytes: Value(reservedBytes),
      attempt: Value(attempt),
      retryAt: Value(retryAt),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
    );
  }

  factory DownloadJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadJob(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      revision: serializer.fromJson<String>(json['revision']),
      manifest: serializer.fromJson<String>(json['manifest']),
      state: serializer.fromJson<String>(json['state']),
      reservedBytes: serializer.fromJson<int>(json['reservedBytes']),
      attempt: serializer.fromJson<int>(json['attempt']),
      retryAt: serializer.fromJson<int>(json['retryAt']),
      error: serializer.fromJson<String?>(json['error']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'revision': serializer.toJson<String>(revision),
      'manifest': serializer.toJson<String>(manifest),
      'state': serializer.toJson<String>(state),
      'reservedBytes': serializer.toJson<int>(reservedBytes),
      'attempt': serializer.toJson<int>(attempt),
      'retryAt': serializer.toJson<int>(retryAt),
      'error': serializer.toJson<String?>(error),
    };
  }

  DownloadJob copyWith({
    String? id,
    String? accountId,
    String? bookId,
    String? revision,
    String? manifest,
    String? state,
    int? reservedBytes,
    int? attempt,
    int? retryAt,
    Value<String?> error = const Value.absent(),
  }) => DownloadJob(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    revision: revision ?? this.revision,
    manifest: manifest ?? this.manifest,
    state: state ?? this.state,
    reservedBytes: reservedBytes ?? this.reservedBytes,
    attempt: attempt ?? this.attempt,
    retryAt: retryAt ?? this.retryAt,
    error: error.present ? error.value : this.error,
  );
  DownloadJob copyWithCompanion(DownloadJobsCompanion data) {
    return DownloadJob(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      revision: data.revision.present ? data.revision.value : this.revision,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
      state: data.state.present ? data.state.value : this.state,
      reservedBytes: data.reservedBytes.present
          ? data.reservedBytes.value
          : this.reservedBytes,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      retryAt: data.retryAt.present ? data.retryAt.value : this.retryAt,
      error: data.error.present ? data.error.value : this.error,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJob(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('manifest: $manifest, ')
          ..write('state: $state, ')
          ..write('reservedBytes: $reservedBytes, ')
          ..write('attempt: $attempt, ')
          ..write('retryAt: $retryAt, ')
          ..write('error: $error')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    bookId,
    revision,
    manifest,
    state,
    reservedBytes,
    attempt,
    retryAt,
    error,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadJob &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.revision == this.revision &&
          other.manifest == this.manifest &&
          other.state == this.state &&
          other.reservedBytes == this.reservedBytes &&
          other.attempt == this.attempt &&
          other.retryAt == this.retryAt &&
          other.error == this.error);
}

class DownloadJobsCompanion extends UpdateCompanion<DownloadJob> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<String> revision;
  final Value<String> manifest;
  final Value<String> state;
  final Value<int> reservedBytes;
  final Value<int> attempt;
  final Value<int> retryAt;
  final Value<String?> error;
  final Value<int> rowid;
  const DownloadJobsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.revision = const Value.absent(),
    this.manifest = const Value.absent(),
    this.state = const Value.absent(),
    this.reservedBytes = const Value.absent(),
    this.attempt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadJobsCompanion.insert({
    required String id,
    required String accountId,
    required String bookId,
    required String revision,
    required String manifest,
    required String state,
    required int reservedBytes,
    this.attempt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.error = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       bookId = Value(bookId),
       revision = Value(revision),
       manifest = Value(manifest),
       state = Value(state),
       reservedBytes = Value(reservedBytes);
  static Insertable<DownloadJob> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<String>? revision,
    Expression<String>? manifest,
    Expression<String>? state,
    Expression<int>? reservedBytes,
    Expression<int>? attempt,
    Expression<int>? retryAt,
    Expression<String>? error,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (revision != null) 'revision': revision,
      if (manifest != null) 'manifest': manifest,
      if (state != null) 'state': state,
      if (reservedBytes != null) 'reserved_bytes': reservedBytes,
      if (attempt != null) 'attempt': attempt,
      if (retryAt != null) 'retry_at': retryAt,
      if (error != null) 'error': error,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? bookId,
    Value<String>? revision,
    Value<String>? manifest,
    Value<String>? state,
    Value<int>? reservedBytes,
    Value<int>? attempt,
    Value<int>? retryAt,
    Value<String?>? error,
    Value<int>? rowid,
  }) {
    return DownloadJobsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      revision: revision ?? this.revision,
      manifest: manifest ?? this.manifest,
      state: state ?? this.state,
      reservedBytes: reservedBytes ?? this.reservedBytes,
      attempt: attempt ?? this.attempt,
      retryAt: retryAt ?? this.retryAt,
      error: error ?? this.error,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(manifest.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (reservedBytes.present) {
      map['reserved_bytes'] = Variable<int>(reservedBytes.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (retryAt.present) {
      map['retry_at'] = Variable<int>(retryAt.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJobsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('revision: $revision, ')
          ..write('manifest: $manifest, ')
          ..write('state: $state, ')
          ..write('reservedBytes: $reservedBytes, ')
          ..write('attempt: $attempt, ')
          ..write('retryAt: $retryAt, ')
          ..write('error: $error, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadPartsTable extends DownloadParts
    with TableInfo<$DownloadPartsTable, DownloadPart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    jobId,
    pageIndex,
    path,
    checksum,
    mediaType,
    byteLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadPart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {jobId, pageIndex};
  @override
  DownloadPart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadPart(
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
    );
  }

  @override
  $DownloadPartsTable createAlias(String alias) {
    return $DownloadPartsTable(attachedDatabase, alias);
  }
}

class DownloadPart extends DataClass implements Insertable<DownloadPart> {
  final String jobId;
  final int pageIndex;
  final String path;
  final String checksum;
  final String mediaType;
  final int byteLength;
  const DownloadPart({
    required this.jobId,
    required this.pageIndex,
    required this.path,
    required this.checksum,
    required this.mediaType,
    required this.byteLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['job_id'] = Variable<String>(jobId);
    map['page_index'] = Variable<int>(pageIndex);
    map['path'] = Variable<String>(path);
    map['checksum'] = Variable<String>(checksum);
    map['media_type'] = Variable<String>(mediaType);
    map['byte_length'] = Variable<int>(byteLength);
    return map;
  }

  DownloadPartsCompanion toCompanion(bool nullToAbsent) {
    return DownloadPartsCompanion(
      jobId: Value(jobId),
      pageIndex: Value(pageIndex),
      path: Value(path),
      checksum: Value(checksum),
      mediaType: Value(mediaType),
      byteLength: Value(byteLength),
    );
  }

  factory DownloadPart.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadPart(
      jobId: serializer.fromJson<String>(json['jobId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      path: serializer.fromJson<String>(json['path']),
      checksum: serializer.fromJson<String>(json['checksum']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'jobId': serializer.toJson<String>(jobId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'path': serializer.toJson<String>(path),
      'checksum': serializer.toJson<String>(checksum),
      'mediaType': serializer.toJson<String>(mediaType),
      'byteLength': serializer.toJson<int>(byteLength),
    };
  }

  DownloadPart copyWith({
    String? jobId,
    int? pageIndex,
    String? path,
    String? checksum,
    String? mediaType,
    int? byteLength,
  }) => DownloadPart(
    jobId: jobId ?? this.jobId,
    pageIndex: pageIndex ?? this.pageIndex,
    path: path ?? this.path,
    checksum: checksum ?? this.checksum,
    mediaType: mediaType ?? this.mediaType,
    byteLength: byteLength ?? this.byteLength,
  );
  DownloadPart copyWithCompanion(DownloadPartsCompanion data) {
    return DownloadPart(
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      path: data.path.present ? data.path.value : this.path,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadPart(')
          ..write('jobId: $jobId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('path: $path, ')
          ..write('checksum: $checksum, ')
          ..write('mediaType: $mediaType, ')
          ..write('byteLength: $byteLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(jobId, pageIndex, path, checksum, mediaType, byteLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadPart &&
          other.jobId == this.jobId &&
          other.pageIndex == this.pageIndex &&
          other.path == this.path &&
          other.checksum == this.checksum &&
          other.mediaType == this.mediaType &&
          other.byteLength == this.byteLength);
}

class DownloadPartsCompanion extends UpdateCompanion<DownloadPart> {
  final Value<String> jobId;
  final Value<int> pageIndex;
  final Value<String> path;
  final Value<String> checksum;
  final Value<String> mediaType;
  final Value<int> byteLength;
  final Value<int> rowid;
  const DownloadPartsCompanion({
    this.jobId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.path = const Value.absent(),
    this.checksum = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadPartsCompanion.insert({
    required String jobId,
    required int pageIndex,
    required String path,
    required String checksum,
    required String mediaType,
    required int byteLength,
    this.rowid = const Value.absent(),
  }) : jobId = Value(jobId),
       pageIndex = Value(pageIndex),
       path = Value(path),
       checksum = Value(checksum),
       mediaType = Value(mediaType),
       byteLength = Value(byteLength);
  static Insertable<DownloadPart> custom({
    Expression<String>? jobId,
    Expression<int>? pageIndex,
    Expression<String>? path,
    Expression<String>? checksum,
    Expression<String>? mediaType,
    Expression<int>? byteLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (jobId != null) 'job_id': jobId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (path != null) 'path': path,
      if (checksum != null) 'checksum': checksum,
      if (mediaType != null) 'media_type': mediaType,
      if (byteLength != null) 'byte_length': byteLength,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadPartsCompanion copyWith({
    Value<String>? jobId,
    Value<int>? pageIndex,
    Value<String>? path,
    Value<String>? checksum,
    Value<String>? mediaType,
    Value<int>? byteLength,
    Value<int>? rowid,
  }) {
    return DownloadPartsCompanion(
      jobId: jobId ?? this.jobId,
      pageIndex: pageIndex ?? this.pageIndex,
      path: path ?? this.path,
      checksum: checksum ?? this.checksum,
      mediaType: mediaType ?? this.mediaType,
      byteLength: byteLength ?? this.byteLength,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadPartsCompanion(')
          ..write('jobId: $jobId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('path: $path, ')
          ..write('checksum: $checksum, ')
          ..write('mediaType: $mediaType, ')
          ..write('byteLength: $byteLength, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressHeadsTable extends ProgressHeads
    with TableInfo<$ProgressHeadsTable, ProgressHead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressHeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineMeta = const VerificationMeta(
    'baseline',
  );
  @override
  late final GeneratedColumn<String> baseline = GeneratedColumn<String>(
    'baseline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, bookId, sequence, baseline];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_heads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressHead> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('baseline')) {
      context.handle(
        _baselineMeta,
        baseline.isAcceptableOrUnknown(data['baseline']!, _baselineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, bookId};
  @override
  ProgressHead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressHead(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      baseline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline'],
      ),
    );
  }

  @override
  $ProgressHeadsTable createAlias(String alias) {
    return $ProgressHeadsTable(attachedDatabase, alias);
  }
}

class ProgressHead extends DataClass implements Insertable<ProgressHead> {
  final String accountId;
  final String bookId;
  final int sequence;
  final String? baseline;
  const ProgressHead({
    required this.accountId,
    required this.bookId,
    required this.sequence,
    this.baseline,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['sequence'] = Variable<int>(sequence);
    if (!nullToAbsent || baseline != null) {
      map['baseline'] = Variable<String>(baseline);
    }
    return map;
  }

  ProgressHeadsCompanion toCompanion(bool nullToAbsent) {
    return ProgressHeadsCompanion(
      accountId: Value(accountId),
      bookId: Value(bookId),
      sequence: Value(sequence),
      baseline: baseline == null && nullToAbsent
          ? const Value.absent()
          : Value(baseline),
    );
  }

  factory ProgressHead.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressHead(
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      baseline: serializer.fromJson<String?>(json['baseline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'sequence': serializer.toJson<int>(sequence),
      'baseline': serializer.toJson<String?>(baseline),
    };
  }

  ProgressHead copyWith({
    String? accountId,
    String? bookId,
    int? sequence,
    Value<String?> baseline = const Value.absent(),
  }) => ProgressHead(
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    sequence: sequence ?? this.sequence,
    baseline: baseline.present ? baseline.value : this.baseline,
  );
  ProgressHead copyWithCompanion(ProgressHeadsCompanion data) {
    return ProgressHead(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      baseline: data.baseline.present ? data.baseline.value : this.baseline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressHead(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('sequence: $sequence, ')
          ..write('baseline: $baseline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, bookId, sequence, baseline);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressHead &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.sequence == this.sequence &&
          other.baseline == this.baseline);
}

class ProgressHeadsCompanion extends UpdateCompanion<ProgressHead> {
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<int> sequence;
  final Value<String?> baseline;
  final Value<int> rowid;
  const ProgressHeadsCompanion({
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.baseline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressHeadsCompanion.insert({
    required String accountId,
    required String bookId,
    required int sequence,
    this.baseline = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       bookId = Value(bookId),
       sequence = Value(sequence);
  static Insertable<ProgressHead> custom({
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<int>? sequence,
    Expression<String>? baseline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (sequence != null) 'sequence': sequence,
      if (baseline != null) 'baseline': baseline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressHeadsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? bookId,
    Value<int>? sequence,
    Value<String?>? baseline,
    Value<int>? rowid,
  }) {
    return ProgressHeadsCompanion(
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      sequence: sequence ?? this.sequence,
      baseline: baseline ?? this.baseline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (baseline.present) {
      map['baseline'] = Variable<String>(baseline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressHeadsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('sequence: $sequence, ')
          ..write('baseline: $baseline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressEventsTable extends ProgressEvents
    with TableInfo<$ProgressEventsTable, ProgressEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentLocatorMeta = const VerificationMeta(
    'documentLocator',
  );
  @override
  late final GeneratedColumn<String> documentLocator = GeneratedColumn<String>(
    'document_locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fractionMeta = const VerificationMeta(
    'fraction',
  );
  @override
  late final GeneratedColumn<double> fraction = GeneratedColumn<double>(
    'fraction',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineMeta = const VerificationMeta(
    'baseline',
  );
  @override
  late final GeneratedColumn<String> baseline = GeneratedColumn<String>(
    'baseline',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteMeta = const VerificationMeta('remote');
  @override
  late final GeneratedColumn<String> remote = GeneratedColumn<String>(
    'remote',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _retryAtMeta = const VerificationMeta(
    'retryAt',
  );
  @override
  late final GeneratedColumn<int> retryAt = GeneratedColumn<int>(
    'retry_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentLocator,
    pageCount,
    accountId,
    bookId,
    sequence,
    revision,
    pageIndex,
    fraction,
    operation,
    baseline,
    state,
    remote,
    attempt,
    retryAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_locator')) {
      context.handle(
        _documentLocatorMeta,
        documentLocator.isAcceptableOrUnknown(
          data['document_locator']!,
          _documentLocatorMeta,
        ),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('fraction')) {
      context.handle(
        _fractionMeta,
        fraction.isAcceptableOrUnknown(data['fraction']!, _fractionMeta),
      );
    } else if (isInserting) {
      context.missing(_fractionMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('baseline')) {
      context.handle(
        _baselineMeta,
        baseline.isAcceptableOrUnknown(data['baseline']!, _baselineMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('remote')) {
      context.handle(
        _remoteMeta,
        remote.isAcceptableOrUnknown(data['remote']!, _remoteMeta),
      );
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('retry_at')) {
      context.handle(
        _retryAtMeta,
        retryAt.isAcceptableOrUnknown(data['retry_at']!, _retryAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, bookId, sequence};
  @override
  ProgressEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressEvent(
      documentLocator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_locator'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      fraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fraction'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      baseline: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      remote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote'],
      ),
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      retryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_at'],
      )!,
    );
  }

  @override
  $ProgressEventsTable createAlias(String alias) {
    return $ProgressEventsTable(attachedDatabase, alias);
  }
}

class ProgressEvent extends DataClass implements Insertable<ProgressEvent> {
  final String? documentLocator;
  final int pageCount;
  final String accountId;
  final String bookId;
  final int sequence;
  final String revision;
  final int pageIndex;
  final double fraction;
  final String operation;
  final String? baseline;
  final String state;
  final String? remote;
  final int attempt;
  final int retryAt;
  const ProgressEvent({
    this.documentLocator,
    required this.pageCount,
    required this.accountId,
    required this.bookId,
    required this.sequence,
    required this.revision,
    required this.pageIndex,
    required this.fraction,
    required this.operation,
    this.baseline,
    required this.state,
    this.remote,
    required this.attempt,
    required this.retryAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || documentLocator != null) {
      map['document_locator'] = Variable<String>(documentLocator);
    }
    map['page_count'] = Variable<int>(pageCount);
    map['account_id'] = Variable<String>(accountId);
    map['book_id'] = Variable<String>(bookId);
    map['sequence'] = Variable<int>(sequence);
    map['revision'] = Variable<String>(revision);
    map['page_index'] = Variable<int>(pageIndex);
    map['fraction'] = Variable<double>(fraction);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || baseline != null) {
      map['baseline'] = Variable<String>(baseline);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || remote != null) {
      map['remote'] = Variable<String>(remote);
    }
    map['attempt'] = Variable<int>(attempt);
    map['retry_at'] = Variable<int>(retryAt);
    return map;
  }

  ProgressEventsCompanion toCompanion(bool nullToAbsent) {
    return ProgressEventsCompanion(
      documentLocator: documentLocator == null && nullToAbsent
          ? const Value.absent()
          : Value(documentLocator),
      pageCount: Value(pageCount),
      accountId: Value(accountId),
      bookId: Value(bookId),
      sequence: Value(sequence),
      revision: Value(revision),
      pageIndex: Value(pageIndex),
      fraction: Value(fraction),
      operation: Value(operation),
      baseline: baseline == null && nullToAbsent
          ? const Value.absent()
          : Value(baseline),
      state: Value(state),
      remote: remote == null && nullToAbsent
          ? const Value.absent()
          : Value(remote),
      attempt: Value(attempt),
      retryAt: Value(retryAt),
    );
  }

  factory ProgressEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressEvent(
      documentLocator: serializer.fromJson<String?>(json['documentLocator']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      accountId: serializer.fromJson<String>(json['accountId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      revision: serializer.fromJson<String>(json['revision']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      fraction: serializer.fromJson<double>(json['fraction']),
      operation: serializer.fromJson<String>(json['operation']),
      baseline: serializer.fromJson<String?>(json['baseline']),
      state: serializer.fromJson<String>(json['state']),
      remote: serializer.fromJson<String?>(json['remote']),
      attempt: serializer.fromJson<int>(json['attempt']),
      retryAt: serializer.fromJson<int>(json['retryAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentLocator': serializer.toJson<String?>(documentLocator),
      'pageCount': serializer.toJson<int>(pageCount),
      'accountId': serializer.toJson<String>(accountId),
      'bookId': serializer.toJson<String>(bookId),
      'sequence': serializer.toJson<int>(sequence),
      'revision': serializer.toJson<String>(revision),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'fraction': serializer.toJson<double>(fraction),
      'operation': serializer.toJson<String>(operation),
      'baseline': serializer.toJson<String?>(baseline),
      'state': serializer.toJson<String>(state),
      'remote': serializer.toJson<String?>(remote),
      'attempt': serializer.toJson<int>(attempt),
      'retryAt': serializer.toJson<int>(retryAt),
    };
  }

  ProgressEvent copyWith({
    Value<String?> documentLocator = const Value.absent(),
    int? pageCount,
    String? accountId,
    String? bookId,
    int? sequence,
    String? revision,
    int? pageIndex,
    double? fraction,
    String? operation,
    Value<String?> baseline = const Value.absent(),
    String? state,
    Value<String?> remote = const Value.absent(),
    int? attempt,
    int? retryAt,
  }) => ProgressEvent(
    documentLocator: documentLocator.present
        ? documentLocator.value
        : this.documentLocator,
    pageCount: pageCount ?? this.pageCount,
    accountId: accountId ?? this.accountId,
    bookId: bookId ?? this.bookId,
    sequence: sequence ?? this.sequence,
    revision: revision ?? this.revision,
    pageIndex: pageIndex ?? this.pageIndex,
    fraction: fraction ?? this.fraction,
    operation: operation ?? this.operation,
    baseline: baseline.present ? baseline.value : this.baseline,
    state: state ?? this.state,
    remote: remote.present ? remote.value : this.remote,
    attempt: attempt ?? this.attempt,
    retryAt: retryAt ?? this.retryAt,
  );
  ProgressEvent copyWithCompanion(ProgressEventsCompanion data) {
    return ProgressEvent(
      documentLocator: data.documentLocator.present
          ? data.documentLocator.value
          : this.documentLocator,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      revision: data.revision.present ? data.revision.value : this.revision,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      fraction: data.fraction.present ? data.fraction.value : this.fraction,
      operation: data.operation.present ? data.operation.value : this.operation,
      baseline: data.baseline.present ? data.baseline.value : this.baseline,
      state: data.state.present ? data.state.value : this.state,
      remote: data.remote.present ? data.remote.value : this.remote,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      retryAt: data.retryAt.present ? data.retryAt.value : this.retryAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressEvent(')
          ..write('documentLocator: $documentLocator, ')
          ..write('pageCount: $pageCount, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('sequence: $sequence, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('fraction: $fraction, ')
          ..write('operation: $operation, ')
          ..write('baseline: $baseline, ')
          ..write('state: $state, ')
          ..write('remote: $remote, ')
          ..write('attempt: $attempt, ')
          ..write('retryAt: $retryAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentLocator,
    pageCount,
    accountId,
    bookId,
    sequence,
    revision,
    pageIndex,
    fraction,
    operation,
    baseline,
    state,
    remote,
    attempt,
    retryAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressEvent &&
          other.documentLocator == this.documentLocator &&
          other.pageCount == this.pageCount &&
          other.accountId == this.accountId &&
          other.bookId == this.bookId &&
          other.sequence == this.sequence &&
          other.revision == this.revision &&
          other.pageIndex == this.pageIndex &&
          other.fraction == this.fraction &&
          other.operation == this.operation &&
          other.baseline == this.baseline &&
          other.state == this.state &&
          other.remote == this.remote &&
          other.attempt == this.attempt &&
          other.retryAt == this.retryAt);
}

class ProgressEventsCompanion extends UpdateCompanion<ProgressEvent> {
  final Value<String?> documentLocator;
  final Value<int> pageCount;
  final Value<String> accountId;
  final Value<String> bookId;
  final Value<int> sequence;
  final Value<String> revision;
  final Value<int> pageIndex;
  final Value<double> fraction;
  final Value<String> operation;
  final Value<String?> baseline;
  final Value<String> state;
  final Value<String?> remote;
  final Value<int> attempt;
  final Value<int> retryAt;
  final Value<int> rowid;
  const ProgressEventsCompanion({
    this.documentLocator = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.accountId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.revision = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.fraction = const Value.absent(),
    this.operation = const Value.absent(),
    this.baseline = const Value.absent(),
    this.state = const Value.absent(),
    this.remote = const Value.absent(),
    this.attempt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressEventsCompanion.insert({
    this.documentLocator = const Value.absent(),
    required int pageCount,
    required String accountId,
    required String bookId,
    required int sequence,
    required String revision,
    required int pageIndex,
    required double fraction,
    required String operation,
    this.baseline = const Value.absent(),
    required String state,
    this.remote = const Value.absent(),
    this.attempt = const Value.absent(),
    this.retryAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pageCount = Value(pageCount),
       accountId = Value(accountId),
       bookId = Value(bookId),
       sequence = Value(sequence),
       revision = Value(revision),
       pageIndex = Value(pageIndex),
       fraction = Value(fraction),
       operation = Value(operation),
       state = Value(state);
  static Insertable<ProgressEvent> custom({
    Expression<String>? documentLocator,
    Expression<int>? pageCount,
    Expression<String>? accountId,
    Expression<String>? bookId,
    Expression<int>? sequence,
    Expression<String>? revision,
    Expression<int>? pageIndex,
    Expression<double>? fraction,
    Expression<String>? operation,
    Expression<String>? baseline,
    Expression<String>? state,
    Expression<String>? remote,
    Expression<int>? attempt,
    Expression<int>? retryAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentLocator != null) 'document_locator': documentLocator,
      if (pageCount != null) 'page_count': pageCount,
      if (accountId != null) 'account_id': accountId,
      if (bookId != null) 'book_id': bookId,
      if (sequence != null) 'sequence': sequence,
      if (revision != null) 'revision': revision,
      if (pageIndex != null) 'page_index': pageIndex,
      if (fraction != null) 'fraction': fraction,
      if (operation != null) 'operation': operation,
      if (baseline != null) 'baseline': baseline,
      if (state != null) 'state': state,
      if (remote != null) 'remote': remote,
      if (attempt != null) 'attempt': attempt,
      if (retryAt != null) 'retry_at': retryAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressEventsCompanion copyWith({
    Value<String?>? documentLocator,
    Value<int>? pageCount,
    Value<String>? accountId,
    Value<String>? bookId,
    Value<int>? sequence,
    Value<String>? revision,
    Value<int>? pageIndex,
    Value<double>? fraction,
    Value<String>? operation,
    Value<String?>? baseline,
    Value<String>? state,
    Value<String?>? remote,
    Value<int>? attempt,
    Value<int>? retryAt,
    Value<int>? rowid,
  }) {
    return ProgressEventsCompanion(
      documentLocator: documentLocator ?? this.documentLocator,
      pageCount: pageCount ?? this.pageCount,
      accountId: accountId ?? this.accountId,
      bookId: bookId ?? this.bookId,
      sequence: sequence ?? this.sequence,
      revision: revision ?? this.revision,
      pageIndex: pageIndex ?? this.pageIndex,
      fraction: fraction ?? this.fraction,
      operation: operation ?? this.operation,
      baseline: baseline ?? this.baseline,
      state: state ?? this.state,
      remote: remote ?? this.remote,
      attempt: attempt ?? this.attempt,
      retryAt: retryAt ?? this.retryAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentLocator.present) {
      map['document_locator'] = Variable<String>(documentLocator.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (fraction.present) {
      map['fraction'] = Variable<double>(fraction.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (baseline.present) {
      map['baseline'] = Variable<String>(baseline.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (remote.present) {
      map['remote'] = Variable<String>(remote.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (retryAt.present) {
      map['retry_at'] = Variable<int>(retryAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressEventsCompanion(')
          ..write('documentLocator: $documentLocator, ')
          ..write('pageCount: $pageCount, ')
          ..write('accountId: $accountId, ')
          ..write('bookId: $bookId, ')
          ..write('sequence: $sequence, ')
          ..write('revision: $revision, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('fraction: $fraction, ')
          ..write('operation: $operation, ')
          ..write('baseline: $baseline, ')
          ..write('state: $state, ')
          ..write('remote: $remote, ')
          ..write('attempt: $attempt, ')
          ..write('retryAt: $retryAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final String key;
  final String payload;
  const AppPreference({required this.key, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(key: Value(key), payload: Value(payload));
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
    };
  }

  AppPreference copyWith({String? key, String? payload}) =>
      AppPreference(key: key ?? this.key, payload: payload ?? this.payload);
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('key: $key, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.key == this.key &&
          other.payload == this.payload);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<String> key;
  final Value<String> payload;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String payload,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload);
  static Insertable<AppPreference> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResumeSnapshotsTable extends ResumeSnapshots
    with TableInfo<$ResumeSnapshotsTable, ResumeSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResumeSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resume_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResumeSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  ResumeSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResumeSnapshot(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ResumeSnapshotsTable createAlias(String alias) {
    return $ResumeSnapshotsTable(attachedDatabase, alias);
  }
}

class ResumeSnapshot extends DataClass implements Insertable<ResumeSnapshot> {
  final String accountId;
  final String payload;
  final DateTime updatedAt;
  const ResumeSnapshot({
    required this.accountId,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ResumeSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ResumeSnapshotsCompanion(
      accountId: Value(accountId),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory ResumeSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResumeSnapshot(
      accountId: serializer.fromJson<String>(json['accountId']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ResumeSnapshot copyWith({
    String? accountId,
    String? payload,
    DateTime? updatedAt,
  }) => ResumeSnapshot(
    accountId: accountId ?? this.accountId,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ResumeSnapshot copyWithCompanion(ResumeSnapshotsCompanion data) {
    return ResumeSnapshot(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResumeSnapshot(')
          ..write('accountId: $accountId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResumeSnapshot &&
          other.accountId == this.accountId &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class ResumeSnapshotsCompanion extends UpdateCompanion<ResumeSnapshot> {
  final Value<String> accountId;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ResumeSnapshotsCompanion({
    this.accountId = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResumeSnapshotsCompanion.insert({
    required String accountId,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<ResumeSnapshot> custom({
    Expression<String>? accountId,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResumeSnapshotsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ResumeSnapshotsCompanion(
      accountId: accountId ?? this.accountId,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResumeSnapshotsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerProfilesTable serverProfiles = $ServerProfilesTable(this);
  late final $CatalogueEntriesTable catalogueEntries = $CatalogueEntriesTable(
    this,
  );
  late final $CatalogueMembershipsTable catalogueMemberships =
      $CatalogueMembershipsTable(this);
  late final $CatalogueSnapshotsTable catalogueSnapshots =
      $CatalogueSnapshotsTable(this);
  late final $ReaderManifestsTable readerManifests = $ReaderManifestsTable(
    this,
  );
  late final $ReaderAssetsTable readerAssets = $ReaderAssetsTable(this);
  late final $ReaderDownloadsTable readerDownloads = $ReaderDownloadsTable(
    this,
  );
  late final $ReadingPreferencesTable readingPreferences =
      $ReadingPreferencesTable(this);
  late final $ReaderPositionsTable readerPositions = $ReaderPositionsTable(
    this,
  );
  late final $OfflineSettingsTable offlineSettings = $OfflineSettingsTable(
    this,
  );
  late final $DownloadJobsTable downloadJobs = $DownloadJobsTable(this);
  late final $DownloadPartsTable downloadParts = $DownloadPartsTable(this);
  late final $ProgressHeadsTable progressHeads = $ProgressHeadsTable(this);
  late final $ProgressEventsTable progressEvents = $ProgressEventsTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $ResumeSnapshotsTable resumeSnapshots = $ResumeSnapshotsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    serverProfiles,
    catalogueEntries,
    catalogueMemberships,
    catalogueSnapshots,
    readerManifests,
    readerAssets,
    readerDownloads,
    readingPreferences,
    readerPositions,
    offlineSettings,
    downloadJobs,
    downloadParts,
    progressHeads,
    progressEvents,
    appPreferences,
    resumeSnapshots,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ServerProfilesTableCreateCompanionBuilder =
    ServerProfilesCompanion Function({
      required String id,
      required String displayName,
      required String baseUrl,
      Value<int> rowid,
    });
typedef $$ServerProfilesTableUpdateCompanionBuilder =
    ServerProfilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> baseUrl,
      Value<int> rowid,
    });

class $$ServerProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);
}

class $$ServerProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerProfilesTable,
          ServerProfile,
          $$ServerProfilesTableFilterComposer,
          $$ServerProfilesTableOrderingComposer,
          $$ServerProfilesTableAnnotationComposer,
          $$ServerProfilesTableCreateCompanionBuilder,
          $$ServerProfilesTableUpdateCompanionBuilder,
          (
            ServerProfile,
            BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerProfile>,
          ),
          ServerProfile,
          PrefetchHooks Function()
        > {
  $$ServerProfilesTableTableManager(
    _$AppDatabase db,
    $ServerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerProfilesCompanion(
                id: id,
                displayName: displayName,
                baseUrl: baseUrl,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String baseUrl,
                Value<int> rowid = const Value.absent(),
              }) => ServerProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                baseUrl: baseUrl,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ServerProfilesTable, ServerProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ServerProfilesTable,
                    ServerProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerProfilesTable,
      ServerProfile,
      $$ServerProfilesTableFilterComposer,
      $$ServerProfilesTableOrderingComposer,
      $$ServerProfilesTableAnnotationComposer,
      $$ServerProfilesTableCreateCompanionBuilder,
      $$ServerProfilesTableUpdateCompanionBuilder,
      (
        ServerProfile,
        BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerProfile>,
      ),
      ServerProfile,
      PrefetchHooks Function()
    >;
typedef $$CatalogueEntriesTableCreateCompanionBuilder =
    CatalogueEntriesCompanion Function({
      required String accountId,
      required String generation,
      required String kind,
      required String remoteId,
      required String title,
      required String sortTitle,
      required String summary,
      required String searchText,
      Value<String?> libraryId,
      Value<String?> seriesId,
      required double number,
      required int itemCount,
      required int pageCount,
      required int modified,
      required bool deleted,
      required bool available,
      required bool ordered,
      Value<String> descriptiveMetadata,
      Value<int> rowid,
    });
typedef $$CatalogueEntriesTableUpdateCompanionBuilder =
    CatalogueEntriesCompanion Function({
      Value<String> accountId,
      Value<String> generation,
      Value<String> kind,
      Value<String> remoteId,
      Value<String> title,
      Value<String> sortTitle,
      Value<String> summary,
      Value<String> searchText,
      Value<String?> libraryId,
      Value<String?> seriesId,
      Value<double> number,
      Value<int> itemCount,
      Value<int> pageCount,
      Value<int> modified,
      Value<bool> deleted,
      Value<bool> available,
      Value<bool> ordered,
      Value<String> descriptiveMetadata,
      Value<int> rowid,
    });

class $$CatalogueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogueEntriesTable> {
  $$CatalogueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryId => $composableBuilder(
    column: $table.libraryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get available => $composableBuilder(
    column: $table.available,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ordered => $composableBuilder(
    column: $table.ordered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descriptiveMetadata => $composableBuilder(
    column: $table.descriptiveMetadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogueEntriesTable> {
  $$CatalogueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortTitle => $composableBuilder(
    column: $table.sortTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryId => $composableBuilder(
    column: $table.libraryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesId => $composableBuilder(
    column: $table.seriesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modified => $composableBuilder(
    column: $table.modified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get available => $composableBuilder(
    column: $table.available,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ordered => $composableBuilder(
    column: $table.ordered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptiveMetadata => $composableBuilder(
    column: $table.descriptiveMetadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogueEntriesTable> {
  $$CatalogueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sortTitle =>
      $composableBuilder(column: $table.sortTitle, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get libraryId =>
      $composableBuilder(column: $table.libraryId, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<double> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get available =>
      $composableBuilder(column: $table.available, builder: (column) => column);

  GeneratedColumn<bool> get ordered =>
      $composableBuilder(column: $table.ordered, builder: (column) => column);

  GeneratedColumn<String> get descriptiveMetadata => $composableBuilder(
    column: $table.descriptiveMetadata,
    builder: (column) => column,
  );
}

class $$CatalogueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogueEntriesTable,
          CatalogueEntry,
          $$CatalogueEntriesTableFilterComposer,
          $$CatalogueEntriesTableOrderingComposer,
          $$CatalogueEntriesTableAnnotationComposer,
          $$CatalogueEntriesTableCreateCompanionBuilder,
          $$CatalogueEntriesTableUpdateCompanionBuilder,
          (
            CatalogueEntry,
            BaseReferences<
              _$AppDatabase,
              $CatalogueEntriesTable,
              CatalogueEntry
            >,
          ),
          CatalogueEntry,
          PrefetchHooks Function()
        > {
  $$CatalogueEntriesTableTableManager(
    _$AppDatabase db,
    $CatalogueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> generation = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sortTitle = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<String?> libraryId = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                Value<double> number = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<int> modified = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> available = const Value.absent(),
                Value<bool> ordered = const Value.absent(),
                Value<String> descriptiveMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogueEntriesCompanion(
                accountId: accountId,
                generation: generation,
                kind: kind,
                remoteId: remoteId,
                title: title,
                sortTitle: sortTitle,
                summary: summary,
                searchText: searchText,
                libraryId: libraryId,
                seriesId: seriesId,
                number: number,
                itemCount: itemCount,
                pageCount: pageCount,
                modified: modified,
                deleted: deleted,
                available: available,
                ordered: ordered,
                descriptiveMetadata: descriptiveMetadata,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String generation,
                required String kind,
                required String remoteId,
                required String title,
                required String sortTitle,
                required String summary,
                required String searchText,
                Value<String?> libraryId = const Value.absent(),
                Value<String?> seriesId = const Value.absent(),
                required double number,
                required int itemCount,
                required int pageCount,
                required int modified,
                required bool deleted,
                required bool available,
                required bool ordered,
                Value<String> descriptiveMetadata = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogueEntriesCompanion.insert(
                accountId: accountId,
                generation: generation,
                kind: kind,
                remoteId: remoteId,
                title: title,
                sortTitle: sortTitle,
                summary: summary,
                searchText: searchText,
                libraryId: libraryId,
                seriesId: seriesId,
                number: number,
                itemCount: itemCount,
                pageCount: pageCount,
                modified: modified,
                deleted: deleted,
                available: available,
                ordered: ordered,
                descriptiveMetadata: descriptiveMetadata,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogueEntriesTable, CatalogueEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogueEntriesTable,
                    CatalogueEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogueEntriesTable,
      CatalogueEntry,
      $$CatalogueEntriesTableFilterComposer,
      $$CatalogueEntriesTableOrderingComposer,
      $$CatalogueEntriesTableAnnotationComposer,
      $$CatalogueEntriesTableCreateCompanionBuilder,
      $$CatalogueEntriesTableUpdateCompanionBuilder,
      (
        CatalogueEntry,
        BaseReferences<_$AppDatabase, $CatalogueEntriesTable, CatalogueEntry>,
      ),
      CatalogueEntry,
      PrefetchHooks Function()
    >;
typedef $$CatalogueMembershipsTableCreateCompanionBuilder =
    CatalogueMembershipsCompanion Function({
      required String accountId,
      required String generation,
      required String groupKind,
      required String groupId,
      required String itemKind,
      required String itemId,
      required int position,
      required bool removed,
      Value<int> rowid,
    });
typedef $$CatalogueMembershipsTableUpdateCompanionBuilder =
    CatalogueMembershipsCompanion Function({
      Value<String> accountId,
      Value<String> generation,
      Value<String> groupKind,
      Value<String> groupId,
      Value<String> itemKind,
      Value<String> itemId,
      Value<int> position,
      Value<bool> removed,
      Value<int> rowid,
    });

class $$CatalogueMembershipsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogueMembershipsTable> {
  $$CatalogueMembershipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupKind => $composableBuilder(
    column: $table.groupKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogueMembershipsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogueMembershipsTable> {
  $$CatalogueMembershipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupKind => $composableBuilder(
    column: $table.groupKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get removed => $composableBuilder(
    column: $table.removed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogueMembershipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogueMembershipsTable> {
  $$CatalogueMembershipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupKind =>
      $composableBuilder(column: $table.groupKind, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get itemKind =>
      $composableBuilder(column: $table.itemKind, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);
}

class $$CatalogueMembershipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogueMembershipsTable,
          CatalogueMembership,
          $$CatalogueMembershipsTableFilterComposer,
          $$CatalogueMembershipsTableOrderingComposer,
          $$CatalogueMembershipsTableAnnotationComposer,
          $$CatalogueMembershipsTableCreateCompanionBuilder,
          $$CatalogueMembershipsTableUpdateCompanionBuilder,
          (
            CatalogueMembership,
            BaseReferences<
              _$AppDatabase,
              $CatalogueMembershipsTable,
              CatalogueMembership
            >,
          ),
          CatalogueMembership,
          PrefetchHooks Function()
        > {
  $$CatalogueMembershipsTableTableManager(
    _$AppDatabase db,
    $CatalogueMembershipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogueMembershipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogueMembershipsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatalogueMembershipsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> generation = const Value.absent(),
                Value<String> groupKind = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> itemKind = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> removed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogueMembershipsCompanion(
                accountId: accountId,
                generation: generation,
                groupKind: groupKind,
                groupId: groupId,
                itemKind: itemKind,
                itemId: itemId,
                position: position,
                removed: removed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String generation,
                required String groupKind,
                required String groupId,
                required String itemKind,
                required String itemId,
                required int position,
                required bool removed,
                Value<int> rowid = const Value.absent(),
              }) => CatalogueMembershipsCompanion.insert(
                accountId: accountId,
                generation: generation,
                groupKind: groupKind,
                groupId: groupId,
                itemKind: itemKind,
                itemId: itemId,
                position: position,
                removed: removed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogueMembershipsTable, CatalogueMembership>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogueMembershipsTable,
                    CatalogueMembership
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogueMembershipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogueMembershipsTable,
      CatalogueMembership,
      $$CatalogueMembershipsTableFilterComposer,
      $$CatalogueMembershipsTableOrderingComposer,
      $$CatalogueMembershipsTableAnnotationComposer,
      $$CatalogueMembershipsTableCreateCompanionBuilder,
      $$CatalogueMembershipsTableUpdateCompanionBuilder,
      (
        CatalogueMembership,
        BaseReferences<
          _$AppDatabase,
          $CatalogueMembershipsTable,
          CatalogueMembership
        >,
      ),
      CatalogueMembership,
      PrefetchHooks Function()
    >;
typedef $$CatalogueSnapshotsTableCreateCompanionBuilder =
    CatalogueSnapshotsCompanion Function({
      required String accountId,
      required String generation,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CatalogueSnapshotsTableUpdateCompanionBuilder =
    CatalogueSnapshotsCompanion Function({
      Value<String> accountId,
      Value<String> generation,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CatalogueSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogueSnapshotsTable> {
  $$CatalogueSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogueSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogueSnapshotsTable> {
  $$CatalogueSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogueSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogueSnapshotsTable> {
  $$CatalogueSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatalogueSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogueSnapshotsTable,
          CatalogueSnapshot,
          $$CatalogueSnapshotsTableFilterComposer,
          $$CatalogueSnapshotsTableOrderingComposer,
          $$CatalogueSnapshotsTableAnnotationComposer,
          $$CatalogueSnapshotsTableCreateCompanionBuilder,
          $$CatalogueSnapshotsTableUpdateCompanionBuilder,
          (
            CatalogueSnapshot,
            BaseReferences<
              _$AppDatabase,
              $CatalogueSnapshotsTable,
              CatalogueSnapshot
            >,
          ),
          CatalogueSnapshot,
          PrefetchHooks Function()
        > {
  $$CatalogueSnapshotsTableTableManager(
    _$AppDatabase db,
    $CatalogueSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogueSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogueSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogueSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> generation = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogueSnapshotsCompanion(
                accountId: accountId,
                generation: generation,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String generation,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatalogueSnapshotsCompanion.insert(
                accountId: accountId,
                generation: generation,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogueSnapshotsTable, CatalogueSnapshot>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogueSnapshotsTable,
                    CatalogueSnapshot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogueSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogueSnapshotsTable,
      CatalogueSnapshot,
      $$CatalogueSnapshotsTableFilterComposer,
      $$CatalogueSnapshotsTableOrderingComposer,
      $$CatalogueSnapshotsTableAnnotationComposer,
      $$CatalogueSnapshotsTableCreateCompanionBuilder,
      $$CatalogueSnapshotsTableUpdateCompanionBuilder,
      (
        CatalogueSnapshot,
        BaseReferences<
          _$AppDatabase,
          $CatalogueSnapshotsTable,
          CatalogueSnapshot
        >,
      ),
      CatalogueSnapshot,
      PrefetchHooks Function()
    >;
typedef $$ReaderManifestsTableCreateCompanionBuilder =
    ReaderManifestsCompanion Function({
      required String accountId,
      required String bookId,
      required String payload,
      Value<int> rowid,
    });
typedef $$ReaderManifestsTableUpdateCompanionBuilder =
    ReaderManifestsCompanion Function({
      Value<String> accountId,
      Value<String> bookId,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ReaderManifestsTableFilterComposer
    extends Composer<_$AppDatabase, $ReaderManifestsTable> {
  $$ReaderManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderManifestsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReaderManifestsTable> {
  $$ReaderManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderManifestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReaderManifestsTable> {
  $$ReaderManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ReaderManifestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReaderManifestsTable,
          StoredReaderManifest,
          $$ReaderManifestsTableFilterComposer,
          $$ReaderManifestsTableOrderingComposer,
          $$ReaderManifestsTableAnnotationComposer,
          $$ReaderManifestsTableCreateCompanionBuilder,
          $$ReaderManifestsTableUpdateCompanionBuilder,
          (
            StoredReaderManifest,
            BaseReferences<
              _$AppDatabase,
              $ReaderManifestsTable,
              StoredReaderManifest
            >,
          ),
          StoredReaderManifest,
          PrefetchHooks Function()
        > {
  $$ReaderManifestsTableTableManager(
    _$AppDatabase db,
    $ReaderManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderManifestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderManifestsCompanion(
                accountId: accountId,
                bookId: bookId,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String bookId,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ReaderManifestsCompanion.insert(
                accountId: accountId,
                bookId: bookId,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReaderManifestsTable, StoredReaderManifest>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReaderManifestsTable,
                    StoredReaderManifest
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReaderManifestsTable,
      StoredReaderManifest,
      $$ReaderManifestsTableFilterComposer,
      $$ReaderManifestsTableOrderingComposer,
      $$ReaderManifestsTableAnnotationComposer,
      $$ReaderManifestsTableCreateCompanionBuilder,
      $$ReaderManifestsTableUpdateCompanionBuilder,
      (
        StoredReaderManifest,
        BaseReferences<
          _$AppDatabase,
          $ReaderManifestsTable,
          StoredReaderManifest
        >,
      ),
      StoredReaderManifest,
      PrefetchHooks Function()
    >;
typedef $$ReaderAssetsTableCreateCompanionBuilder =
    ReaderAssetsCompanion Function({
      required String assetId,
      required String tier,
      required String accountId,
      required String bookId,
      required String revision,
      required int pageIndex,
      required String representation,
      required String checksum,
      required String mediaType,
      required int byteLength,
      required DateTime lastAccess,
      Value<int> rowid,
    });
typedef $$ReaderAssetsTableUpdateCompanionBuilder =
    ReaderAssetsCompanion Function({
      Value<String> assetId,
      Value<String> tier,
      Value<String> accountId,
      Value<String> bookId,
      Value<String> revision,
      Value<int> pageIndex,
      Value<String> representation,
      Value<String> checksum,
      Value<String> mediaType,
      Value<int> byteLength,
      Value<DateTime> lastAccess,
      Value<int> rowid,
    });

class $$ReaderAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $ReaderAssetsTable> {
  $$ReaderAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReaderAssetsTable> {
  $$ReaderAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReaderAssetsTable> {
  $$ReaderAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get representation => $composableBuilder(
    column: $table.representation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => column,
  );
}

class $$ReaderAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReaderAssetsTable,
          ReaderAsset,
          $$ReaderAssetsTableFilterComposer,
          $$ReaderAssetsTableOrderingComposer,
          $$ReaderAssetsTableAnnotationComposer,
          $$ReaderAssetsTableCreateCompanionBuilder,
          $$ReaderAssetsTableUpdateCompanionBuilder,
          (
            ReaderAsset,
            BaseReferences<_$AppDatabase, $ReaderAssetsTable, ReaderAsset>,
          ),
          ReaderAsset,
          PrefetchHooks Function()
        > {
  $$ReaderAssetsTableTableManager(_$AppDatabase db, $ReaderAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<String> tier = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> representation = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> byteLength = const Value.absent(),
                Value<DateTime> lastAccess = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderAssetsCompanion(
                assetId: assetId,
                tier: tier,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                pageIndex: pageIndex,
                representation: representation,
                checksum: checksum,
                mediaType: mediaType,
                byteLength: byteLength,
                lastAccess: lastAccess,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required String tier,
                required String accountId,
                required String bookId,
                required String revision,
                required int pageIndex,
                required String representation,
                required String checksum,
                required String mediaType,
                required int byteLength,
                required DateTime lastAccess,
                Value<int> rowid = const Value.absent(),
              }) => ReaderAssetsCompanion.insert(
                assetId: assetId,
                tier: tier,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                pageIndex: pageIndex,
                representation: representation,
                checksum: checksum,
                mediaType: mediaType,
                byteLength: byteLength,
                lastAccess: lastAccess,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReaderAssetsTable, ReaderAsset>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReaderAssetsTable,
                    ReaderAsset
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReaderAssetsTable,
      ReaderAsset,
      $$ReaderAssetsTableFilterComposer,
      $$ReaderAssetsTableOrderingComposer,
      $$ReaderAssetsTableAnnotationComposer,
      $$ReaderAssetsTableCreateCompanionBuilder,
      $$ReaderAssetsTableUpdateCompanionBuilder,
      (
        ReaderAsset,
        BaseReferences<_$AppDatabase, $ReaderAssetsTable, ReaderAsset>,
      ),
      ReaderAsset,
      PrefetchHooks Function()
    >;
typedef $$ReaderDownloadsTableCreateCompanionBuilder =
    ReaderDownloadsCompanion Function({
      required String accountId,
      required String bookId,
      required String revision,
      Value<int> rowid,
    });
typedef $$ReaderDownloadsTableUpdateCompanionBuilder =
    ReaderDownloadsCompanion Function({
      Value<String> accountId,
      Value<String> bookId,
      Value<String> revision,
      Value<int> rowid,
    });

class $$ReaderDownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $ReaderDownloadsTable> {
  $$ReaderDownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderDownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReaderDownloadsTable> {
  $$ReaderDownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderDownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReaderDownloadsTable> {
  $$ReaderDownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$ReaderDownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReaderDownloadsTable,
          ReaderDownload,
          $$ReaderDownloadsTableFilterComposer,
          $$ReaderDownloadsTableOrderingComposer,
          $$ReaderDownloadsTableAnnotationComposer,
          $$ReaderDownloadsTableCreateCompanionBuilder,
          $$ReaderDownloadsTableUpdateCompanionBuilder,
          (
            ReaderDownload,
            BaseReferences<
              _$AppDatabase,
              $ReaderDownloadsTable,
              ReaderDownload
            >,
          ),
          ReaderDownload,
          PrefetchHooks Function()
        > {
  $$ReaderDownloadsTableTableManager(
    _$AppDatabase db,
    $ReaderDownloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderDownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderDownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderDownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderDownloadsCompanion(
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String bookId,
                required String revision,
                Value<int> rowid = const Value.absent(),
              }) => ReaderDownloadsCompanion.insert(
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReaderDownloadsTable, ReaderDownload>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReaderDownloadsTable,
                    ReaderDownload
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderDownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReaderDownloadsTable,
      ReaderDownload,
      $$ReaderDownloadsTableFilterComposer,
      $$ReaderDownloadsTableOrderingComposer,
      $$ReaderDownloadsTableAnnotationComposer,
      $$ReaderDownloadsTableCreateCompanionBuilder,
      $$ReaderDownloadsTableUpdateCompanionBuilder,
      (
        ReaderDownload,
        BaseReferences<_$AppDatabase, $ReaderDownloadsTable, ReaderDownload>,
      ),
      ReaderDownload,
      PrefetchHooks Function()
    >;
typedef $$ReadingPreferencesTableCreateCompanionBuilder =
    ReadingPreferencesCompanion Function({
      required String accountId,
      required String scope,
      required String scopeId,
      required String payload,
      Value<int> rowid,
    });
typedef $$ReadingPreferencesTableUpdateCompanionBuilder =
    ReadingPreferencesCompanion Function({
      Value<String> accountId,
      Value<String> scope,
      Value<String> scopeId,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ReadingPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingPreferencesTable> {
  $$ReadingPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingPreferencesTable> {
  $$ReadingPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingPreferencesTable> {
  $$ReadingPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ReadingPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingPreferencesTable,
          ReadingPreference,
          $$ReadingPreferencesTableFilterComposer,
          $$ReadingPreferencesTableOrderingComposer,
          $$ReadingPreferencesTableAnnotationComposer,
          $$ReadingPreferencesTableCreateCompanionBuilder,
          $$ReadingPreferencesTableUpdateCompanionBuilder,
          (
            ReadingPreference,
            BaseReferences<
              _$AppDatabase,
              $ReadingPreferencesTable,
              ReadingPreference
            >,
          ),
          ReadingPreference,
          PrefetchHooks Function()
        > {
  $$ReadingPreferencesTableTableManager(
    _$AppDatabase db,
    $ReadingPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingPreferencesCompanion(
                accountId: accountId,
                scope: scope,
                scopeId: scopeId,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String scope,
                required String scopeId,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ReadingPreferencesCompanion.insert(
                accountId: accountId,
                scope: scope,
                scopeId: scopeId,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingPreferencesTable, ReadingPreference>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReadingPreferencesTable,
                    ReadingPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingPreferencesTable,
      ReadingPreference,
      $$ReadingPreferencesTableFilterComposer,
      $$ReadingPreferencesTableOrderingComposer,
      $$ReadingPreferencesTableAnnotationComposer,
      $$ReadingPreferencesTableCreateCompanionBuilder,
      $$ReadingPreferencesTableUpdateCompanionBuilder,
      (
        ReadingPreference,
        BaseReferences<
          _$AppDatabase,
          $ReadingPreferencesTable,
          ReadingPreference
        >,
      ),
      ReadingPreference,
      PrefetchHooks Function()
    >;
typedef $$ReaderPositionsTableCreateCompanionBuilder =
    ReaderPositionsCompanion Function({
      Value<String?> documentLocator,
      required String accountId,
      required String bookId,
      required String revision,
      required int pageIndex,
      required double fraction,
      Value<int> rowid,
    });
typedef $$ReaderPositionsTableUpdateCompanionBuilder =
    ReaderPositionsCompanion Function({
      Value<String?> documentLocator,
      Value<String> accountId,
      Value<String> bookId,
      Value<String> revision,
      Value<int> pageIndex,
      Value<double> fraction,
      Value<int> rowid,
    });

class $$ReaderPositionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderPositionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderPositionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<double> get fraction =>
      $composableBuilder(column: $table.fraction, builder: (column) => column);
}

class $$ReaderPositionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReaderPositionsTable,
          ReaderPosition,
          $$ReaderPositionsTableFilterComposer,
          $$ReaderPositionsTableOrderingComposer,
          $$ReaderPositionsTableAnnotationComposer,
          $$ReaderPositionsTableCreateCompanionBuilder,
          $$ReaderPositionsTableUpdateCompanionBuilder,
          (
            ReaderPosition,
            BaseReferences<
              _$AppDatabase,
              $ReaderPositionsTable,
              ReaderPosition
            >,
          ),
          ReaderPosition,
          PrefetchHooks Function()
        > {
  $$ReaderPositionsTableTableManager(
    _$AppDatabase db,
    $ReaderPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> documentLocator = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderPositionsCompanion(
                documentLocator: documentLocator,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                pageIndex: pageIndex,
                fraction: fraction,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> documentLocator = const Value.absent(),
                required String accountId,
                required String bookId,
                required String revision,
                required int pageIndex,
                required double fraction,
                Value<int> rowid = const Value.absent(),
              }) => ReaderPositionsCompanion.insert(
                documentLocator: documentLocator,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                pageIndex: pageIndex,
                fraction: fraction,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReaderPositionsTable, ReaderPosition>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReaderPositionsTable,
                    ReaderPosition
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReaderPositionsTable,
      ReaderPosition,
      $$ReaderPositionsTableFilterComposer,
      $$ReaderPositionsTableOrderingComposer,
      $$ReaderPositionsTableAnnotationComposer,
      $$ReaderPositionsTableCreateCompanionBuilder,
      $$ReaderPositionsTableUpdateCompanionBuilder,
      (
        ReaderPosition,
        BaseReferences<_$AppDatabase, $ReaderPositionsTable, ReaderPosition>,
      ),
      ReaderPosition,
      PrefetchHooks Function()
    >;
typedef $$OfflineSettingsTableCreateCompanionBuilder =
    OfflineSettingsCompanion Function({
      required String accountId,
      required int quota,
      required bool wifiOnly,
      Value<int> rowid,
    });
typedef $$OfflineSettingsTableUpdateCompanionBuilder =
    OfflineSettingsCompanion Function({
      Value<String> accountId,
      Value<int> quota,
      Value<bool> wifiOnly,
      Value<int> rowid,
    });

class $$OfflineSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineSettingsTable> {
  $$OfflineSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wifiOnly => $composableBuilder(
    column: $table.wifiOnly,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineSettingsTable> {
  $$OfflineSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wifiOnly => $composableBuilder(
    column: $table.wifiOnly,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineSettingsTable> {
  $$OfflineSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get quota =>
      $composableBuilder(column: $table.quota, builder: (column) => column);

  GeneratedColumn<bool> get wifiOnly =>
      $composableBuilder(column: $table.wifiOnly, builder: (column) => column);
}

class $$OfflineSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfflineSettingsTable,
          OfflineSetting,
          $$OfflineSettingsTableFilterComposer,
          $$OfflineSettingsTableOrderingComposer,
          $$OfflineSettingsTableAnnotationComposer,
          $$OfflineSettingsTableCreateCompanionBuilder,
          $$OfflineSettingsTableUpdateCompanionBuilder,
          (
            OfflineSetting,
            BaseReferences<
              _$AppDatabase,
              $OfflineSettingsTable,
              OfflineSetting
            >,
          ),
          OfflineSetting,
          PrefetchHooks Function()
        > {
  $$OfflineSettingsTableTableManager(
    _$AppDatabase db,
    $OfflineSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<int> quota = const Value.absent(),
                Value<bool> wifiOnly = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineSettingsCompanion(
                accountId: accountId,
                quota: quota,
                wifiOnly: wifiOnly,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required int quota,
                required bool wifiOnly,
                Value<int> rowid = const Value.absent(),
              }) => OfflineSettingsCompanion.insert(
                accountId: accountId,
                quota: quota,
                wifiOnly: wifiOnly,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OfflineSettingsTable, OfflineSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OfflineSettingsTable,
                    OfflineSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfflineSettingsTable,
      OfflineSetting,
      $$OfflineSettingsTableFilterComposer,
      $$OfflineSettingsTableOrderingComposer,
      $$OfflineSettingsTableAnnotationComposer,
      $$OfflineSettingsTableCreateCompanionBuilder,
      $$OfflineSettingsTableUpdateCompanionBuilder,
      (
        OfflineSetting,
        BaseReferences<_$AppDatabase, $OfflineSettingsTable, OfflineSetting>,
      ),
      OfflineSetting,
      PrefetchHooks Function()
    >;
typedef $$DownloadJobsTableCreateCompanionBuilder =
    DownloadJobsCompanion Function({
      required String id,
      required String accountId,
      required String bookId,
      required String revision,
      required String manifest,
      required String state,
      required int reservedBytes,
      Value<int> attempt,
      Value<int> retryAt,
      Value<String?> error,
      Value<int> rowid,
    });
typedef $$DownloadJobsTableUpdateCompanionBuilder =
    DownloadJobsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> bookId,
      Value<String> revision,
      Value<String> manifest,
      Value<String> state,
      Value<int> reservedBytes,
      Value<int> attempt,
      Value<int> retryAt,
      Value<String?> error,
      Value<int> rowid,
    });

class $$DownloadJobsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reservedBytes => $composableBuilder(
    column: $table.reservedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reservedBytes => $composableBuilder(
    column: $table.reservedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get manifest =>
      $composableBuilder(column: $table.manifest, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get reservedBytes => $composableBuilder(
    column: $table.reservedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<int> get retryAt =>
      $composableBuilder(column: $table.retryAt, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);
}

class $$DownloadJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadJobsTable,
          DownloadJob,
          $$DownloadJobsTableFilterComposer,
          $$DownloadJobsTableOrderingComposer,
          $$DownloadJobsTableAnnotationComposer,
          $$DownloadJobsTableCreateCompanionBuilder,
          $$DownloadJobsTableUpdateCompanionBuilder,
          (
            DownloadJob,
            BaseReferences<_$AppDatabase, $DownloadJobsTable, DownloadJob>,
          ),
          DownloadJob,
          PrefetchHooks Function()
        > {
  $$DownloadJobsTableTableManager(_$AppDatabase db, $DownloadJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<String> manifest = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> reservedBytes = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> retryAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadJobsCompanion(
                id: id,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                manifest: manifest,
                state: state,
                reservedBytes: reservedBytes,
                attempt: attempt,
                retryAt: retryAt,
                error: error,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String bookId,
                required String revision,
                required String manifest,
                required String state,
                required int reservedBytes,
                Value<int> attempt = const Value.absent(),
                Value<int> retryAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadJobsCompanion.insert(
                id: id,
                accountId: accountId,
                bookId: bookId,
                revision: revision,
                manifest: manifest,
                state: state,
                reservedBytes: reservedBytes,
                attempt: attempt,
                retryAt: retryAt,
                error: error,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadJobsTable, DownloadJob>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DownloadJobsTable,
                    DownloadJob
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadJobsTable,
      DownloadJob,
      $$DownloadJobsTableFilterComposer,
      $$DownloadJobsTableOrderingComposer,
      $$DownloadJobsTableAnnotationComposer,
      $$DownloadJobsTableCreateCompanionBuilder,
      $$DownloadJobsTableUpdateCompanionBuilder,
      (
        DownloadJob,
        BaseReferences<_$AppDatabase, $DownloadJobsTable, DownloadJob>,
      ),
      DownloadJob,
      PrefetchHooks Function()
    >;
typedef $$DownloadPartsTableCreateCompanionBuilder =
    DownloadPartsCompanion Function({
      required String jobId,
      required int pageIndex,
      required String path,
      required String checksum,
      required String mediaType,
      required int byteLength,
      Value<int> rowid,
    });
typedef $$DownloadPartsTableUpdateCompanionBuilder =
    DownloadPartsCompanion Function({
      Value<String> jobId,
      Value<int> pageIndex,
      Value<String> path,
      Value<String> checksum,
      Value<String> mediaType,
      Value<int> byteLength,
      Value<int> rowid,
    });

class $$DownloadPartsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadPartsTable> {
  $$DownloadPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadPartsTable> {
  $$DownloadPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadPartsTable> {
  $$DownloadPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );
}

class $$DownloadPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadPartsTable,
          DownloadPart,
          $$DownloadPartsTableFilterComposer,
          $$DownloadPartsTableOrderingComposer,
          $$DownloadPartsTableAnnotationComposer,
          $$DownloadPartsTableCreateCompanionBuilder,
          $$DownloadPartsTableUpdateCompanionBuilder,
          (
            DownloadPart,
            BaseReferences<_$AppDatabase, $DownloadPartsTable, DownloadPart>,
          ),
          DownloadPart,
          PrefetchHooks Function()
        > {
  $$DownloadPartsTableTableManager(_$AppDatabase db, $DownloadPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> jobId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> byteLength = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadPartsCompanion(
                jobId: jobId,
                pageIndex: pageIndex,
                path: path,
                checksum: checksum,
                mediaType: mediaType,
                byteLength: byteLength,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String jobId,
                required int pageIndex,
                required String path,
                required String checksum,
                required String mediaType,
                required int byteLength,
                Value<int> rowid = const Value.absent(),
              }) => DownloadPartsCompanion.insert(
                jobId: jobId,
                pageIndex: pageIndex,
                path: path,
                checksum: checksum,
                mediaType: mediaType,
                byteLength: byteLength,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadPartsTable, DownloadPart>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DownloadPartsTable,
                    DownloadPart
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadPartsTable,
      DownloadPart,
      $$DownloadPartsTableFilterComposer,
      $$DownloadPartsTableOrderingComposer,
      $$DownloadPartsTableAnnotationComposer,
      $$DownloadPartsTableCreateCompanionBuilder,
      $$DownloadPartsTableUpdateCompanionBuilder,
      (
        DownloadPart,
        BaseReferences<_$AppDatabase, $DownloadPartsTable, DownloadPart>,
      ),
      DownloadPart,
      PrefetchHooks Function()
    >;
typedef $$ProgressHeadsTableCreateCompanionBuilder =
    ProgressHeadsCompanion Function({
      required String accountId,
      required String bookId,
      required int sequence,
      Value<String?> baseline,
      Value<int> rowid,
    });
typedef $$ProgressHeadsTableUpdateCompanionBuilder =
    ProgressHeadsCompanion Function({
      Value<String> accountId,
      Value<String> bookId,
      Value<int> sequence,
      Value<String?> baseline,
      Value<int> rowid,
    });

class $$ProgressHeadsTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressHeadsTable> {
  $$ProgressHeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseline => $composableBuilder(
    column: $table.baseline,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressHeadsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressHeadsTable> {
  $$ProgressHeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseline => $composableBuilder(
    column: $table.baseline,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressHeadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressHeadsTable> {
  $$ProgressHeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get baseline =>
      $composableBuilder(column: $table.baseline, builder: (column) => column);
}

class $$ProgressHeadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressHeadsTable,
          ProgressHead,
          $$ProgressHeadsTableFilterComposer,
          $$ProgressHeadsTableOrderingComposer,
          $$ProgressHeadsTableAnnotationComposer,
          $$ProgressHeadsTableCreateCompanionBuilder,
          $$ProgressHeadsTableUpdateCompanionBuilder,
          (
            ProgressHead,
            BaseReferences<_$AppDatabase, $ProgressHeadsTable, ProgressHead>,
          ),
          ProgressHead,
          PrefetchHooks Function()
        > {
  $$ProgressHeadsTableTableManager(_$AppDatabase db, $ProgressHeadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressHeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressHeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressHeadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String?> baseline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressHeadsCompanion(
                accountId: accountId,
                bookId: bookId,
                sequence: sequence,
                baseline: baseline,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String bookId,
                required int sequence,
                Value<String?> baseline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressHeadsCompanion.insert(
                accountId: accountId,
                bookId: bookId,
                sequence: sequence,
                baseline: baseline,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressHeadsTable, ProgressHead>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProgressHeadsTable,
                    ProgressHead
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressHeadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressHeadsTable,
      ProgressHead,
      $$ProgressHeadsTableFilterComposer,
      $$ProgressHeadsTableOrderingComposer,
      $$ProgressHeadsTableAnnotationComposer,
      $$ProgressHeadsTableCreateCompanionBuilder,
      $$ProgressHeadsTableUpdateCompanionBuilder,
      (
        ProgressHead,
        BaseReferences<_$AppDatabase, $ProgressHeadsTable, ProgressHead>,
      ),
      ProgressHead,
      PrefetchHooks Function()
    >;
typedef $$ProgressEventsTableCreateCompanionBuilder =
    ProgressEventsCompanion Function({
      Value<String?> documentLocator,
      required int pageCount,
      required String accountId,
      required String bookId,
      required int sequence,
      required String revision,
      required int pageIndex,
      required double fraction,
      required String operation,
      Value<String?> baseline,
      required String state,
      Value<String?> remote,
      Value<int> attempt,
      Value<int> retryAt,
      Value<int> rowid,
    });
typedef $$ProgressEventsTableUpdateCompanionBuilder =
    ProgressEventsCompanion Function({
      Value<String?> documentLocator,
      Value<int> pageCount,
      Value<String> accountId,
      Value<String> bookId,
      Value<int> sequence,
      Value<String> revision,
      Value<int> pageIndex,
      Value<double> fraction,
      Value<String> operation,
      Value<String?> baseline,
      Value<String> state,
      Value<String?> remote,
      Value<int> attempt,
      Value<int> retryAt,
      Value<int> rowid,
    });

class $$ProgressEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressEventsTable> {
  $$ProgressEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseline => $composableBuilder(
    column: $table.baseline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remote => $composableBuilder(
    column: $table.remote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressEventsTable> {
  $$ProgressEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fraction => $composableBuilder(
    column: $table.fraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseline => $composableBuilder(
    column: $table.baseline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remote => $composableBuilder(
    column: $table.remote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryAt => $composableBuilder(
    column: $table.retryAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressEventsTable> {
  $$ProgressEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentLocator => $composableBuilder(
    column: $table.documentLocator,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<double> get fraction =>
      $composableBuilder(column: $table.fraction, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get baseline =>
      $composableBuilder(column: $table.baseline, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get remote =>
      $composableBuilder(column: $table.remote, builder: (column) => column);

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<int> get retryAt =>
      $composableBuilder(column: $table.retryAt, builder: (column) => column);
}

class $$ProgressEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressEventsTable,
          ProgressEvent,
          $$ProgressEventsTableFilterComposer,
          $$ProgressEventsTableOrderingComposer,
          $$ProgressEventsTableAnnotationComposer,
          $$ProgressEventsTableCreateCompanionBuilder,
          $$ProgressEventsTableUpdateCompanionBuilder,
          (
            ProgressEvent,
            BaseReferences<_$AppDatabase, $ProgressEventsTable, ProgressEvent>,
          ),
          ProgressEvent,
          PrefetchHooks Function()
        > {
  $$ProgressEventsTableTableManager(
    _$AppDatabase db,
    $ProgressEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> documentLocator = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<double> fraction = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> baseline = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> remote = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> retryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressEventsCompanion(
                documentLocator: documentLocator,
                pageCount: pageCount,
                accountId: accountId,
                bookId: bookId,
                sequence: sequence,
                revision: revision,
                pageIndex: pageIndex,
                fraction: fraction,
                operation: operation,
                baseline: baseline,
                state: state,
                remote: remote,
                attempt: attempt,
                retryAt: retryAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> documentLocator = const Value.absent(),
                required int pageCount,
                required String accountId,
                required String bookId,
                required int sequence,
                required String revision,
                required int pageIndex,
                required double fraction,
                required String operation,
                Value<String?> baseline = const Value.absent(),
                required String state,
                Value<String?> remote = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<int> retryAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressEventsCompanion.insert(
                documentLocator: documentLocator,
                pageCount: pageCount,
                accountId: accountId,
                bookId: bookId,
                sequence: sequence,
                revision: revision,
                pageIndex: pageIndex,
                fraction: fraction,
                operation: operation,
                baseline: baseline,
                state: state,
                remote: remote,
                attempt: attempt,
                retryAt: retryAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressEventsTable, ProgressEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ProgressEventsTable,
                    ProgressEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressEventsTable,
      ProgressEvent,
      $$ProgressEventsTableFilterComposer,
      $$ProgressEventsTableOrderingComposer,
      $$ProgressEventsTableAnnotationComposer,
      $$ProgressEventsTableCreateCompanionBuilder,
      $$ProgressEventsTableUpdateCompanionBuilder,
      (
        ProgressEvent,
        BaseReferences<_$AppDatabase, $ProgressEventsTable, ProgressEvent>,
      ),
      ProgressEvent,
      PrefetchHooks Function()
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String payload,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreference,
            BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
          ),
          AppPreference,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion(
                key: key,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppPreferencesTable, AppPreference>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AppPreferencesTable,
                    AppPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreference,
        BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference>,
      ),
      AppPreference,
      PrefetchHooks Function()
    >;
typedef $$ResumeSnapshotsTableCreateCompanionBuilder =
    ResumeSnapshotsCompanion Function({
      required String accountId,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ResumeSnapshotsTableUpdateCompanionBuilder =
    ResumeSnapshotsCompanion Function({
      Value<String> accountId,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ResumeSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $ResumeSnapshotsTable> {
  $$ResumeSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResumeSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ResumeSnapshotsTable> {
  $$ResumeSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResumeSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResumeSnapshotsTable> {
  $$ResumeSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ResumeSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResumeSnapshotsTable,
          ResumeSnapshot,
          $$ResumeSnapshotsTableFilterComposer,
          $$ResumeSnapshotsTableOrderingComposer,
          $$ResumeSnapshotsTableAnnotationComposer,
          $$ResumeSnapshotsTableCreateCompanionBuilder,
          $$ResumeSnapshotsTableUpdateCompanionBuilder,
          (
            ResumeSnapshot,
            BaseReferences<
              _$AppDatabase,
              $ResumeSnapshotsTable,
              ResumeSnapshot
            >,
          ),
          ResumeSnapshot,
          PrefetchHooks Function()
        > {
  $$ResumeSnapshotsTableTableManager(
    _$AppDatabase db,
    $ResumeSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResumeSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResumeSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResumeSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResumeSnapshotsCompanion(
                accountId: accountId,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ResumeSnapshotsCompanion.insert(
                accountId: accountId,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResumeSnapshotsTable, ResumeSnapshot>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ResumeSnapshotsTable,
                    ResumeSnapshot
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResumeSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResumeSnapshotsTable,
      ResumeSnapshot,
      $$ResumeSnapshotsTableFilterComposer,
      $$ResumeSnapshotsTableOrderingComposer,
      $$ResumeSnapshotsTableAnnotationComposer,
      $$ResumeSnapshotsTableCreateCompanionBuilder,
      $$ResumeSnapshotsTableUpdateCompanionBuilder,
      (
        ResumeSnapshot,
        BaseReferences<_$AppDatabase, $ResumeSnapshotsTable, ResumeSnapshot>,
      ),
      ResumeSnapshot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerProfilesTableTableManager get serverProfiles =>
      $$ServerProfilesTableTableManager(_db, _db.serverProfiles);
  $$CatalogueEntriesTableTableManager get catalogueEntries =>
      $$CatalogueEntriesTableTableManager(_db, _db.catalogueEntries);
  $$CatalogueMembershipsTableTableManager get catalogueMemberships =>
      $$CatalogueMembershipsTableTableManager(_db, _db.catalogueMemberships);
  $$CatalogueSnapshotsTableTableManager get catalogueSnapshots =>
      $$CatalogueSnapshotsTableTableManager(_db, _db.catalogueSnapshots);
  $$ReaderManifestsTableTableManager get readerManifests =>
      $$ReaderManifestsTableTableManager(_db, _db.readerManifests);
  $$ReaderAssetsTableTableManager get readerAssets =>
      $$ReaderAssetsTableTableManager(_db, _db.readerAssets);
  $$ReaderDownloadsTableTableManager get readerDownloads =>
      $$ReaderDownloadsTableTableManager(_db, _db.readerDownloads);
  $$ReadingPreferencesTableTableManager get readingPreferences =>
      $$ReadingPreferencesTableTableManager(_db, _db.readingPreferences);
  $$ReaderPositionsTableTableManager get readerPositions =>
      $$ReaderPositionsTableTableManager(_db, _db.readerPositions);
  $$OfflineSettingsTableTableManager get offlineSettings =>
      $$OfflineSettingsTableTableManager(_db, _db.offlineSettings);
  $$DownloadJobsTableTableManager get downloadJobs =>
      $$DownloadJobsTableTableManager(_db, _db.downloadJobs);
  $$DownloadPartsTableTableManager get downloadParts =>
      $$DownloadPartsTableTableManager(_db, _db.downloadParts);
  $$ProgressHeadsTableTableManager get progressHeads =>
      $$ProgressHeadsTableTableManager(_db, _db.progressHeads);
  $$ProgressEventsTableTableManager get progressEvents =>
      $$ProgressEventsTableTableManager(_db, _db.progressEvents);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$ResumeSnapshotsTableTableManager get resumeSnapshots =>
      $$ResumeSnapshotsTableTableManager(_db, _db.resumeSnapshots);
}
