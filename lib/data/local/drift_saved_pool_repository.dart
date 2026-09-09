import 'package:drift/drift.dart';
import 'package:waketok/data/local/saved_pool_id.dart';
import 'package:waketok/data/local/waketok_database.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_recipe.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';
import 'package:waketok/domain/source/source_reference.dart';

class DriftSavedPoolRepository implements SavedPoolRepository {
  DriftSavedPoolRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? createId,
  })  : _clock = clock ?? DateTime.now,
        _createId = createId ?? createSavedPoolId;

  final WaketokDatabase _db;
  final DateTime Function() _clock;
  final String Function() _createId;

  @override
  Future<List<SavedPoolRecord>> loadAll() async {
    final rows = await (_db.select(_db.savedPools)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    if (rows.isEmpty) {
      return const [];
    }
    final sourcesByPool = await _sourcesGroupedByPool();
    return [
      for (final row in rows)
        _recordFromRow(row, sourcesByPool[row.id] ?? const []),
    ];
  }

  @override
  Future<SavedPoolRecord?> loadById(String id) async {
    final row = await (_db.select(_db.savedPools)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    final sources = await _sourcesForPool(id);
    return _recordFromRow(row, sources);
  }

  @override
  Future<SavedPoolRecord> save({
    required String displayName,
    required List<SourceReference> orderedSourceReferences,
  }) async {
    final name = requireSavedPoolDisplayName(displayName);
    ensureSavedPoolRecipe(orderedSourceReferences);
    final key = savedPoolDisplayNameKey(name);
    final id = _createId();
    final millis = _clock().millisecondsSinceEpoch;

    return _db.transaction(() async {
      final existing = await _db.select(_db.savedPools).get();
      if (existing.length >= PoolCapacity.maxSavedPoolPresets) {
        throw const SavedPoolCapacityExceeded();
      }
      final existingRecords = <SavedPoolRecord>[
        for (final row in existing)
          _recordFromRow(row, await _sourcesForPool(row.id)),
      ];
      final recipeClash = findSavedPoolWithSameRecipe(
        candidate: orderedSourceReferences,
        existing: existingRecords,
      );
      if (recipeClash != null) {
        throw SavedPoolDuplicateRecipe(
          existingDisplayName: recipeClash.displayName,
        );
      }
      final clash = existing.where((row) => row.displayNameKey == key);
      if (clash.isNotEmpty) {
        throw const SavedPoolDuplicateName();
      }

      await _db.into(_db.savedPools).insert(
            SavedPoolsCompanion.insert(
              id: id,
              displayName: name,
              displayNameKey: key,
              createdAt: millis,
              updatedAt: millis,
            ),
          );
      await _insertSources(id, orderedSourceReferences);
      return SavedPoolRecord(
        id: id,
        displayName: name,
        createdAt: _utcFromMillis(millis),
        updatedAt: _utcFromMillis(millis),
        orderedSourceReferences: orderedSourceReferences,
      );
    });
  }

  @override
  Future<SavedPoolRecord> rename({
    required String id,
    required String displayName,
  }) async {
    final name = requireSavedPoolDisplayName(displayName);
    final key = savedPoolDisplayNameKey(name);
    final millis = _clock().millisecondsSinceEpoch;

    return _db.transaction(() async {
      final row = await (_db.select(_db.savedPools)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) {
        throw const SavedPoolNotFound();
      }
      if (row.displayNameKey != key) {
        final clash = await (_db.select(_db.savedPools)
              ..where((t) => t.displayNameKey.equals(key)))
            .getSingleOrNull();
        if (clash != null) {
          throw const SavedPoolDuplicateName();
        }
      }

      await (_db.update(_db.savedPools)..where((t) => t.id.equals(id))).write(
        SavedPoolsCompanion(
          displayName: Value(name),
          displayNameKey: Value(key),
          updatedAt: Value(millis),
        ),
      );
      final sources = await _sourcesForPool(id);
      return SavedPoolRecord(
        id: id,
        displayName: name,
        createdAt: _utcFromMillis(row.createdAt),
        updatedAt: _utcFromMillis(millis),
        orderedSourceReferences: sources,
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.savedPools)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _insertSources(
    String poolId,
    List<SourceReference> refs,
  ) async {
    for (var i = 0; i < refs.length; i++) {
      final ref = refs[i];
      await _db.into(_db.savedPoolSources).insert(
            SavedPoolSourcesCompanion.insert(
              poolId: poolId,
              position: i,
              sourceKind: ref.kind.name,
              sourceId: ref.id,
            ),
          );
    }
  }

  Future<List<SourceReference>> _sourcesForPool(String poolId) async {
    final rows = await (_db.select(_db.savedPoolSources)
          ..where((t) => t.poolId.equals(poolId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return [for (final row in rows) _sourceFromRow(row)];
  }

  Future<Map<String, List<SourceReference>>> _sourcesGroupedByPool() async {
    final rows = await (_db.select(_db.savedPoolSources)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    final grouped = <String, List<SourceReference>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.poolId, () => []).add(_sourceFromRow(row));
    }
    return grouped;
  }

  SavedPoolRecord _recordFromRow(
    SavedPool row,
    List<SourceReference> sources,
  ) {
    return SavedPoolRecord(
      id: row.id,
      displayName: row.displayName,
      createdAt: _utcFromMillis(row.createdAt),
      updatedAt: _utcFromMillis(row.updatedAt),
      orderedSourceReferences: sources,
    );
  }

  SourceReference _sourceFromRow(SavedPoolSource row) {
    return SourceReference(
      kind: AssetSourceKind.values.byName(row.sourceKind),
      id: row.sourceId,
    );
  }

  DateTime _utcFromMillis(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
