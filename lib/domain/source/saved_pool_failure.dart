/// Typed failures for Saved Pool persistence (Cap 22 / ADR-046).
///
/// Domain repositories throw these (existing port convention). [Result] stays
/// the ADR-008 platform-boundary type — not a CRUD return wrapper.
sealed class SavedPoolException implements Exception {
  const SavedPoolException();
}

/// Already at [PoolCapacity.maxSavedPoolPresets]; insert is refused.
final class SavedPoolCapacityExceeded extends SavedPoolException {
  const SavedPoolCapacityExceeded();
}

/// Normalized displayName collides with another Saved preset.
final class SavedPoolDuplicateName extends SavedPoolException {
  const SavedPoolDuplicateName();
}

/// Display name is empty after trim.
final class SavedPoolInvalidName extends SavedPoolException {
  const SavedPoolInvalidName();
}

/// Recipe is empty, exceeds max sources, or has an empty source id.
final class SavedPoolInvalidRecipe extends SavedPoolException {
  const SavedPoolInvalidRecipe();
}

/// Ordered source recipe matches another Saved preset (create refused).
final class SavedPoolDuplicateRecipe extends SavedPoolException {
  const SavedPoolDuplicateRecipe({required this.existingDisplayName});

  /// Display name of the first matching preset ([loadAll] order).
  final String existingDisplayName;
}

/// [SavedPoolRepository.rename] target id is not in the store.
final class SavedPoolNotFound extends SavedPoolException {
  const SavedPoolNotFound();
}
