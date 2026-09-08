import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
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
