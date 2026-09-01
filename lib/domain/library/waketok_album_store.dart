/// Persists the canonical WakeTok User Album [localIdentifier] (Cap 19 D1).
abstract class WakeTokAlbumStore {
  Future<String?> loadAlbumId();

  Future<void> saveAlbumId(String albumIdentifier);

  Future<void> clearAlbumId();
}
