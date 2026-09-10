/// Cap 24 — soft-delete current asset into system Recently Deleted.
///
/// Host uses `PHAssetChangeRequest.deleteAssets`. Never empties Recently
/// Deleted. Distinct from [AlbumMutationRepository] (membership writes).
abstract class AssetSoftDeleteRepository {
  /// Soft-deletes [assetIdentifier] into Photos Recently Deleted.
  ///
  /// Wire failures use existing ErrorCode names: missing or already in
  /// Recently Deleted → `assetUnavailable`; system confirm cancel →
  /// `operationCancelled` (cancel ≠ failure for App toast).
  Future<void> softDeleteAsset(String assetIdentifier);
}
