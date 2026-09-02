/// Cap 19.2a+ — append-only User Album mutations via PhotoKit (Host).
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
