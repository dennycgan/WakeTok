import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_recipe.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// In-memory [SavedPoolRepository] with the same invariants as Drift.
class FakeSavedPoolRepository implements SavedPoolRepository {
  FakeSavedPoolRepository({
    DateTime Function()? clock,
    String Function()? createId,
  })  : _clock = clock ?? DateTime.now,
        _createId = createId ?? _incrementingId;

  final DateTime Function() _clock;
  final String Function() _createId;
  final List<SavedPoolRecord> _rows = [];
  static int _fallbackSeq = 0;

  static String _incrementingId() => 'fake-pool-${_fallbackSeq++}';

  @override
  Future<List<SavedPoolRecord>> loadAll() async {
    final copy = List<SavedPoolRecord>.from(_rows);
    copy.sort((a, b) {
      final byUpdated = b.updatedAt.compareTo(a.updatedAt);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  @override
  Future<SavedPoolRecord?> loadById(String id) async {
    for (final row in _rows) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  @override
  Future<SavedPoolRecord> save({
    required String displayName,
    required List<SourceReference> orderedSourceReferences,
  }) async {
    final name = requireSavedPoolDisplayName(displayName);
    ensureSavedPoolRecipe(orderedSourceReferences);
    final key = savedPoolDisplayNameKey(name);
    if (_rows.length >= PoolCapacity.maxSavedPoolPresets) {
      throw const SavedPoolCapacityExceeded();
    }
    final recipeClash = findSavedPoolWithSameRecipe(
      candidate: orderedSourceReferences,
      existing: _rows,
    );
    if (recipeClash != null) {
      throw SavedPoolDuplicateRecipe(
        existingDisplayName: recipeClash.displayName,
      );
    }
    if (_rows.any((row) => savedPoolDisplayNameKey(row.displayName) == key)) {
      throw const SavedPoolDuplicateName();
    }
    final millis = _clock().millisecondsSinceEpoch;
    final at = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final record = SavedPoolRecord(
      id: _createId(),
      displayName: name,
      createdAt: at,
      updatedAt: at,
      orderedSourceReferences: orderedSourceReferences,
    );
    _rows.add(record);
    return record;
  }

  @override
  Future<SavedPoolRecord> rename({
    required String id,
    required String displayName,
  }) async {
    final name = requireSavedPoolDisplayName(displayName);
    final key = savedPoolDisplayNameKey(name);
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) {
      throw const SavedPoolNotFound();
    }
    final current = _rows[index];
    if (savedPoolDisplayNameKey(current.displayName) != key) {
      final clash = _rows.any(
        (row) =>
            row.id != id && savedPoolDisplayNameKey(row.displayName) == key,
      );
      if (clash) {
        throw const SavedPoolDuplicateName();
      }
    }
    final millis = _clock().millisecondsSinceEpoch;
    final updated = SavedPoolRecord(
      id: current.id,
      displayName: name,
      createdAt: current.createdAt,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
      orderedSourceReferences: current.orderedSourceReferences,
    );
    _rows[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    _rows.removeWhere((row) => row.id == id);
  }
}
