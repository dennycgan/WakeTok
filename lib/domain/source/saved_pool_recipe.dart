import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Saved-preset recipe shape (stricter than [SourcePoolDefinition]).
///
/// SPD allows 0 sources; a Saved preset must have `1..maxSourcesPerPool`
/// references and non-empty source ids. Does not construct an SPD.
void ensureSavedPoolRecipe(List<SourceReference> orderedSourceReferences) {
  final count = orderedSourceReferences.length;
  if (count == 0 || count > PoolCapacity.maxSourcesPerPool) {
    throw const SavedPoolInvalidRecipe();
  }
  for (final reference in orderedSourceReferences) {
    if (reference.id.isEmpty) {
      throw const SavedPoolInvalidRecipe();
    }
  }
}

/// Ordered recipe equality (same as [SavedPoolRecord] / SPD source lists).
bool savedPoolRecipesEqual(
  List<SourceReference> a,
  List<SourceReference> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// First preset in [existing] whose ordered recipe matches [candidate].
///
/// [existing] order is caller-defined (typically [SavedPoolRepository.loadAll]).
SavedPoolRecord? findSavedPoolWithSameRecipe({
  required List<SourceReference> candidate,
  required Iterable<SavedPoolRecord> existing,
}) {
  for (final row in existing) {
    if (savedPoolRecipesEqual(candidate, row.orderedSourceReferences)) {
      return row;
    }
  }
  return null;
}
