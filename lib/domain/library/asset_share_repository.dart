/// Cap 25 — present the system share sheet for a Photos library asset.
///
/// Host presents `UIActivityViewController` for the current `PHAsset`.
/// Distinct from [AssetSoftDeleteRepository] (library mutation) and
/// [AlbumMutationRepository] (membership writes).
abstract class AssetShareRepository {
  /// Presents the system share sheet for [assetIdentifier].
  ///
  /// Completes when the sheet has been **presented** (or fails before
  /// present). User cancel / successful share of the sheet must not fail
  /// this Future. Wire failures use existing ErrorCode names: missing
  /// asset, cannot build activity items, or no root UIViewController →
  /// `assetUnavailable` (ADR-051 Decision 5 intentional overload). Share
  /// sheet cancel must **not** surface as `operationCancelled`.
  Future<void> presentShareSheet(String assetIdentifier);
}
