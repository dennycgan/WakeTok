import 'package:drift/drift.dart';

/// Saved Pool Preset header (Cap 22 / ADR-046). Always `saved` policy.
class SavedPools extends Table {
  @override
  String get tableName => 'saved_pools';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get displayNameKey => text().unique()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Ordered SourceReferences for a Saved preset. Cascade-deleted with the pool.
class SavedPoolSources extends Table {
  @override
  String get tableName => 'saved_pool_sources';

  TextColumn get poolId => text().references(
        SavedPools,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get position => integer()();
  TextColumn get sourceKind => text()();
  TextColumn get sourceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {poolId, position};
}
