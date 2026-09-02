import 'dart:typed_data';

/// Cap 19.5 — User Album cover thumbnail for Add-to-Album picker rows.
abstract class AlbumCoverRepository {
  Future<Uint8List?> requestCoverThumbnail(
    String albumIdentifier, {
    required int targetSizePx,
  });
}
