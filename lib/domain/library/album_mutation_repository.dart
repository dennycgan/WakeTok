/// Cap 19.2a+ — User Album mutations via PhotoKit (Host).
///
/// Membership writes ([addAssetToAlbum]; future remove-from-album APIs on
/// this surface) must stay here so ADR-048 Snapshot invalidation can hook
/// once at the composition root.
abstract class AlbumMutationRepository {
  Future<String> createAlbum(String name);

  /// Cap 19.7: whether [assetIdentifier] is already in [albumIdentifier].
  Future<bool> albumContainsAsset(
    String albumIdentifier,
    String assetIdentifier,
  );

  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  );
}
