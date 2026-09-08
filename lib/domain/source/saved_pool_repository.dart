import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Persistence port for Saved Pool Presets (Cap 22 / ADR-046 D1–D2).
///
/// Implementations throw [SavedPoolException] subtypes. No Riverpod.
abstract class SavedPoolRepository {
  /// All presets, `updatedAt` descending then `id` ascending.
  Future<List<SavedPoolRecord>> loadAll();

  Future<SavedPoolRecord?> loadById(String id);

  /// Insert-only. Mints a new id. Never upserts recipe (MVP: no edit).
  Future<SavedPoolRecord> save({
    required String displayName,
    required List<SourceReference> orderedSourceReferences,
  });

  Future<SavedPoolRecord> rename({
    required String id,
    required String displayName,
  });

  /// Missing [id] is a no-op success.
  Future<void> delete(String id);
}
