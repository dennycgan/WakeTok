/// ADR-P / ADR-020 capacity constants for Source Pool Definitions.
///
/// [maxSourcesPerPool] is enforced when constructing a SourcePoolDefinition.
/// [maxSavedPoolPresets] is product/cognitive limit only — Cap 10 exposes the
/// constant; Saved Pool CRUD / count enforcement belongs to the Saved Pool
/// capability.
abstract final class PoolCapacity {
  static const int maxSourcesPerPool = 30;
  static const int maxSavedPoolPresets = 10;
}
