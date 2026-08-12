/// Classification of a Resolved Pool for Default Session Profile (ADR-N /
/// ADR-022 D2).
///
/// Cap 12: [generatedClip] / Clip Descriptor types do not exist, so
/// [classifyPoolProfile] always returns [generalMixed].
/// [pureGeneratedClip] is reserved for the Generated Clip Cap.
enum PoolProfileKind {
  /// Kickoff General / Mixed Pool — default Shuffle + Manual + Repeat All.
  generalMixed,

  /// Kickoff Pure Generated Clip Pool — default Sequential + Manual +
  /// Repeat All. Unreachable until Generated Clip specialization lands.
  pureGeneratedClip,
}
