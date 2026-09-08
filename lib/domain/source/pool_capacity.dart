/// ADR-P / ADR-020 capacity constants for Source Pool Definitions.
///
/// [maxSourcesPerPool] is enforced when constructing a SourcePoolDefinition
/// and again on Saved Pool save (stricter: Saved refuses 0 sources).
/// [maxSavedPoolPresets] is enforced on Saved Pool save (Cap 22).
abstract final class PoolCapacity {
  static const int maxSourcesPerPool = 30;
  static const int maxSavedPoolPresets = 10;
}
