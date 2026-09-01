/// Cap 19.2a+ — append-only User Album mutations via PhotoKit (Host).
abstract class AlbumMutationRepository {
  Future<String> createAlbum(String name);

  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  );
}
