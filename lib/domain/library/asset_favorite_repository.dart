/// Cap 19.5b — per-asset Favorites read/write via PhotoKit (Host).
abstract class AssetFavoriteRepository {
  Future<bool> requestFavoriteStatus(String assetIdentifier);

  Future<void> setFavorite(
    String assetIdentifier, {
    required bool favorite,
  });
}
