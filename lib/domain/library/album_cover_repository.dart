import 'dart:typed_data';

/// Cap 19.5 — User Album cover thumbnail for Add-to-Album picker rows.
abstract class AlbumCoverRepository {
  Future<Uint8List?> requestCoverThumbnail(
    String albumIdentifier, {
    required int targetSizePx,
  });

  /// Cap 19.5b — Photos Favorites smart album cover (not the current feed asset).
  Future<Uint8List?> requestFavoritesSmartAlbumCoverThumbnail({
    required int targetSizePx,
  });
}
