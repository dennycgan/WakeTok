// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waketok_database.dart';

// ignore_for_file: type=lint
class $SavedPoolsTable extends SavedPools
    with TableInfo<$SavedPoolsTable, SavedPool> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPoolsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _displayNameKeyMeta = const VerificationMeta(
    'displayNameKey',
  );
  @override
  late final GeneratedColumn<String> displayNameKey = GeneratedColumn<String>(
    'display_name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    displayNameKey,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_pools';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPool> instance, {
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
    if (data.containsKey('display_name_key')) {
      context.handle(
        _displayNameKeyMeta,
        displayNameKey.isAcceptableOrUnknown(
          data['display_name_key']!,
          _displayNameKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedPool map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPool(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      displayNameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SavedPoolsTable createAlias(String alias) {
    return $SavedPoolsTable(attachedDatabase, alias);
  }
}

class SavedPool extends DataClass implements Insertable<SavedPool> {
  final String id;
  final String displayName;
  final String displayNameKey;
  final int createdAt;
  final int updatedAt;
  const SavedPool({
    required this.id,
    required this.displayName,
    required this.displayNameKey,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['display_name_key'] = Variable<String>(displayNameKey);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SavedPoolsCompanion toCompanion(bool nullToAbsent) {
    return SavedPoolsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      displayNameKey: Value(displayNameKey),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SavedPool.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPool(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      displayNameKey: serializer.fromJson<String>(json['displayNameKey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'displayNameKey': serializer.toJson<String>(displayNameKey),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SavedPool copyWith({
    String? id,
    String? displayName,
    String? displayNameKey,
    int? createdAt,
    int? updatedAt,
  }) => SavedPool(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    displayNameKey: displayNameKey ?? this.displayNameKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SavedPool copyWithCompanion(SavedPoolsCompanion data) {
    return SavedPool(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      displayNameKey: data.displayNameKey.present
          ? data.displayNameKey.value
          : this.displayNameKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPool(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('displayNameKey: $displayNameKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, displayNameKey, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPool &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.displayNameKey == this.displayNameKey &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SavedPoolsCompanion extends UpdateCompanion<SavedPool> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> displayNameKey;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SavedPoolsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.displayNameKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedPoolsCompanion.insert({
    required String id,
    required String displayName,
    required String displayNameKey,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       displayNameKey = Value(displayNameKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SavedPool> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? displayNameKey,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (displayNameKey != null) 'display_name_key': displayNameKey,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedPoolsCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? displayNameKey,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SavedPoolsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      displayNameKey: displayNameKey ?? this.displayNameKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (displayNameKey.present) {
      map['display_name_key'] = Variable<String>(displayNameKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPoolsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('displayNameKey: $displayNameKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedPoolSourcesTable extends SavedPoolSources
    with TableInfo<$SavedPoolSourcesTable, SavedPoolSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedPoolSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _poolIdMeta = const VerificationMeta('poolId');
  @override
  late final GeneratedColumn<String> poolId = GeneratedColumn<String>(
    'pool_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES saved_pools (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    poolId,
    position,
    sourceKind,
    sourceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_pool_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedPoolSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pool_id')) {
      context.handle(
        _poolIdMeta,
        poolId.isAcceptableOrUnknown(data['pool_id']!, _poolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poolIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {poolId, position};
  @override
  SavedPoolSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedPoolSource(
      poolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pool_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
    );
  }

  @override
  $SavedPoolSourcesTable createAlias(String alias) {
    return $SavedPoolSourcesTable(attachedDatabase, alias);
  }
}

class SavedPoolSource extends DataClass implements Insertable<SavedPoolSource> {
  final String poolId;
  final int position;
  final String sourceKind;
  final String sourceId;
  const SavedPoolSource({
    required this.poolId,
    required this.position,
    required this.sourceKind,
    required this.sourceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pool_id'] = Variable<String>(poolId);
    map['position'] = Variable<int>(position);
    map['source_kind'] = Variable<String>(sourceKind);
    map['source_id'] = Variable<String>(sourceId);
    return map;
  }

  SavedPoolSourcesCompanion toCompanion(bool nullToAbsent) {
    return SavedPoolSourcesCompanion(
      poolId: Value(poolId),
      position: Value(position),
      sourceKind: Value(sourceKind),
      sourceId: Value(sourceId),
    );
  }

  factory SavedPoolSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedPoolSource(
      poolId: serializer.fromJson<String>(json['poolId']),
      position: serializer.fromJson<int>(json['position']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'poolId': serializer.toJson<String>(poolId),
      'position': serializer.toJson<int>(position),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceId': serializer.toJson<String>(sourceId),
    };
  }

  SavedPoolSource copyWith({
    String? poolId,
    int? position,
    String? sourceKind,
    String? sourceId,
  }) => SavedPoolSource(
    poolId: poolId ?? this.poolId,
    position: position ?? this.position,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceId: sourceId ?? this.sourceId,
  );
  SavedPoolSource copyWithCompanion(SavedPoolSourcesCompanion data) {
    return SavedPoolSource(
      poolId: data.poolId.present ? data.poolId.value : this.poolId,
      position: data.position.present ? data.position.value : this.position,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedPoolSource(')
          ..write('poolId: $poolId, ')
          ..write('position: $position, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(poolId, position, sourceKind, sourceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedPoolSource &&
          other.poolId == this.poolId &&
          other.position == this.position &&
          other.sourceKind == this.sourceKind &&
          other.sourceId == this.sourceId);
}

class SavedPoolSourcesCompanion extends UpdateCompanion<SavedPoolSource> {
  final Value<String> poolId;
  final Value<int> position;
  final Value<String> sourceKind;
  final Value<String> sourceId;
  final Value<int> rowid;
  const SavedPoolSourcesCompanion({
    this.poolId = const Value.absent(),
    this.position = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedPoolSourcesCompanion.insert({
    required String poolId,
    required int position,
    required String sourceKind,
    required String sourceId,
    this.rowid = const Value.absent(),
  }) : poolId = Value(poolId),
       position = Value(position),
       sourceKind = Value(sourceKind),
       sourceId = Value(sourceId);
  static Insertable<SavedPoolSource> custom({
    Expression<String>? poolId,
    Expression<int>? position,
    Expression<String>? sourceKind,
    Expression<String>? sourceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (poolId != null) 'pool_id': poolId,
      if (position != null) 'position': position,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceId != null) 'source_id': sourceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedPoolSourcesCompanion copyWith({
    Value<String>? poolId,
    Value<int>? position,
    Value<String>? sourceKind,
    Value<String>? sourceId,
    Value<int>? rowid,
  }) {
    return SavedPoolSourcesCompanion(
      poolId: poolId ?? this.poolId,
      position: position ?? this.position,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceId: sourceId ?? this.sourceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (poolId.present) {
      map['pool_id'] = Variable<String>(poolId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedPoolSourcesCompanion(')
          ..write('poolId: $poolId, ')
          ..write('position: $position, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceId: $sourceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WaketokDatabase extends GeneratedDatabase {
  _$WaketokDatabase(QueryExecutor e) : super(e);
  $WaketokDatabaseManager get managers => $WaketokDatabaseManager(this);
  late final $SavedPoolsTable savedPools = $SavedPoolsTable(this);
  late final $SavedPoolSourcesTable savedPoolSources = $SavedPoolSourcesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    savedPools,
    savedPoolSources,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'saved_pools',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('saved_pool_sources', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SavedPoolsTableCreateCompanionBuilder =
    SavedPoolsCompanion Function({
      required String id,
      required String displayName,
      required String displayNameKey,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SavedPoolsTableUpdateCompanionBuilder =
    SavedPoolsCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> displayNameKey,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$SavedPoolsTableReferences
    extends BaseReferences<_$WaketokDatabase, $SavedPoolsTable, SavedPool> {
  $$SavedPoolsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SavedPoolSourcesTable, List<SavedPoolSource>>
  _savedPoolSourcesRefsTable(_$WaketokDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.savedPoolSources,
        aliasName: 'saved_pools__id__saved_pool_sources__pool_id',
      );

  $$SavedPoolSourcesTableProcessedTableManager get savedPoolSourcesRefs {
    final manager = $$SavedPoolSourcesTableTableManager(
      $_db,
      $_db.savedPoolSources,
    ).filter((f) => f.poolId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _savedPoolSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SavedPoolsTableFilterComposer
    extends Composer<_$WaketokDatabase, $SavedPoolsTable> {
  $$SavedPoolsTableFilterComposer({
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

  ColumnFilters<String> get displayNameKey => $composableBuilder(
    column: $table.displayNameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> savedPoolSourcesRefs(
    Expression<bool> Function($$SavedPoolSourcesTableFilterComposer f) f,
  ) {
    final $$SavedPoolSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedPoolSources,
      getReferencedColumn: (t) => t.poolId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPoolSourcesTableFilterComposer(
            $db: $db,
            $table: $db.savedPoolSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedPoolsTableOrderingComposer
    extends Composer<_$WaketokDatabase, $SavedPoolsTable> {
  $$SavedPoolsTableOrderingComposer({
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

  ColumnOrderings<String> get displayNameKey => $composableBuilder(
    column: $table.displayNameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedPoolsTableAnnotationComposer
    extends Composer<_$WaketokDatabase, $SavedPoolsTable> {
  $$SavedPoolsTableAnnotationComposer({
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

  GeneratedColumn<String> get displayNameKey => $composableBuilder(
    column: $table.displayNameKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> savedPoolSourcesRefs<T extends Object>(
    Expression<T> Function($$SavedPoolSourcesTableAnnotationComposer a) f,
  ) {
    final $$SavedPoolSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.savedPoolSources,
      getReferencedColumn: (t) => t.poolId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPoolSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.savedPoolSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SavedPoolsTableTableManager
    extends
        RootTableManager<
          _$WaketokDatabase,
          $SavedPoolsTable,
          SavedPool,
          $$SavedPoolsTableFilterComposer,
          $$SavedPoolsTableOrderingComposer,
          $$SavedPoolsTableAnnotationComposer,
          $$SavedPoolsTableCreateCompanionBuilder,
          $$SavedPoolsTableUpdateCompanionBuilder,
          (SavedPool, $$SavedPoolsTableReferences),
          SavedPool,
          PrefetchHooks Function({bool savedPoolSourcesRefs})
        > {
  $$SavedPoolsTableTableManager(_$WaketokDatabase db, $SavedPoolsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPoolsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPoolsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPoolsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> displayNameKey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedPoolsCompanion(
                id: id,
                displayName: displayName,
                displayNameKey: displayNameKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String displayNameKey,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedPoolsCompanion.insert(
                id: id,
                displayName: displayName,
                displayNameKey: displayNameKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedPoolsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({savedPoolSourcesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (savedPoolSourcesRefs) db.savedPoolSources,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (savedPoolSourcesRefs)
                    await $_getPrefetchedData<
                      SavedPool,
                      $SavedPoolsTable,
                      SavedPoolSource
                    >(
                      currentTable: table,
                      referencedTable: $$SavedPoolsTableReferences
                          ._savedPoolSourcesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SavedPoolsTableReferences(
                            db,
                            table,
                            p0,
                          ).savedPoolSourcesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.poolId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SavedPoolsTableProcessedTableManager =
    ProcessedTableManager<
      _$WaketokDatabase,
      $SavedPoolsTable,
      SavedPool,
      $$SavedPoolsTableFilterComposer,
      $$SavedPoolsTableOrderingComposer,
      $$SavedPoolsTableAnnotationComposer,
      $$SavedPoolsTableCreateCompanionBuilder,
      $$SavedPoolsTableUpdateCompanionBuilder,
      (SavedPool, $$SavedPoolsTableReferences),
      SavedPool,
      PrefetchHooks Function({bool savedPoolSourcesRefs})
    >;
typedef $$SavedPoolSourcesTableCreateCompanionBuilder =
    SavedPoolSourcesCompanion Function({
      required String poolId,
      required int position,
      required String sourceKind,
      required String sourceId,
      Value<int> rowid,
    });
typedef $$SavedPoolSourcesTableUpdateCompanionBuilder =
    SavedPoolSourcesCompanion Function({
      Value<String> poolId,
      Value<int> position,
      Value<String> sourceKind,
      Value<String> sourceId,
      Value<int> rowid,
    });

final class $$SavedPoolSourcesTableReferences
    extends
        BaseReferences<
          _$WaketokDatabase,
          $SavedPoolSourcesTable,
          SavedPoolSource
        > {
  $$SavedPoolSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SavedPoolsTable _poolIdTable(_$WaketokDatabase db) =>
      db.savedPools.createAlias('saved_pool_sources__pool_id__saved_pools__id');

  $$SavedPoolsTableProcessedTableManager get poolId {
    final $_column = $_itemColumn<String>('pool_id')!;

    final manager = $$SavedPoolsTableTableManager(
      $_db,
      $_db.savedPools,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poolIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SavedPoolSourcesTableFilterComposer
    extends Composer<_$WaketokDatabase, $SavedPoolSourcesTable> {
  $$SavedPoolSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  $$SavedPoolsTableFilterComposer get poolId {
    final $$SavedPoolsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.savedPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPoolsTableFilterComposer(
            $db: $db,
            $table: $db.savedPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPoolSourcesTableOrderingComposer
    extends Composer<_$WaketokDatabase, $SavedPoolSourcesTable> {
  $$SavedPoolSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$SavedPoolsTableOrderingComposer get poolId {
    final $$SavedPoolsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.savedPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPoolsTableOrderingComposer(
            $db: $db,
            $table: $db.savedPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPoolSourcesTableAnnotationComposer
    extends Composer<_$WaketokDatabase, $SavedPoolSourcesTable> {
  $$SavedPoolSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  $$SavedPoolsTableAnnotationComposer get poolId {
    final $$SavedPoolsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poolId,
      referencedTable: $db.savedPools,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SavedPoolsTableAnnotationComposer(
            $db: $db,
            $table: $db.savedPools,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SavedPoolSourcesTableTableManager
    extends
        RootTableManager<
          _$WaketokDatabase,
          $SavedPoolSourcesTable,
          SavedPoolSource,
          $$SavedPoolSourcesTableFilterComposer,
          $$SavedPoolSourcesTableOrderingComposer,
          $$SavedPoolSourcesTableAnnotationComposer,
          $$SavedPoolSourcesTableCreateCompanionBuilder,
          $$SavedPoolSourcesTableUpdateCompanionBuilder,
          (SavedPoolSource, $$SavedPoolSourcesTableReferences),
          SavedPoolSource,
          PrefetchHooks Function({bool poolId})
        > {
  $$SavedPoolSourcesTableTableManager(
    _$WaketokDatabase db,
    $SavedPoolSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedPoolSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedPoolSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedPoolSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> poolId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedPoolSourcesCompanion(
                poolId: poolId,
                position: position,
                sourceKind: sourceKind,
                sourceId: sourceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String poolId,
                required int position,
                required String sourceKind,
                required String sourceId,
                Value<int> rowid = const Value.absent(),
              }) => SavedPoolSourcesCompanion.insert(
                poolId: poolId,
                position: position,
                sourceKind: sourceKind,
                sourceId: sourceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SavedPoolSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poolId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (poolId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poolId,
                                referencedTable:
                                    $$SavedPoolSourcesTableReferences
                                        ._poolIdTable(db),
                                referencedColumn:
                                    $$SavedPoolSourcesTableReferences
                                        ._poolIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SavedPoolSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$WaketokDatabase,
      $SavedPoolSourcesTable,
      SavedPoolSource,
      $$SavedPoolSourcesTableFilterComposer,
      $$SavedPoolSourcesTableOrderingComposer,
      $$SavedPoolSourcesTableAnnotationComposer,
      $$SavedPoolSourcesTableCreateCompanionBuilder,
      $$SavedPoolSourcesTableUpdateCompanionBuilder,
      (SavedPoolSource, $$SavedPoolSourcesTableReferences),
      SavedPoolSource,
      PrefetchHooks Function({bool poolId})
    >;

class $WaketokDatabaseManager {
  final _$WaketokDatabase _db;
  $WaketokDatabaseManager(this._db);
  $$SavedPoolsTableTableManager get savedPools =>
      $$SavedPoolsTableTableManager(_db, _db.savedPools);
  $$SavedPoolSourcesTableTableManager get savedPoolSources =>
      $$SavedPoolSourcesTableTableManager(_db, _db.savedPoolSources);
}
