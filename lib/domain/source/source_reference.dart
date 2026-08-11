import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

/// Reference to an Asset Source (kind + identifier).
///
/// Cap 6/ADR-013: built-in pairs use frozen short ids (`all` / `photos` /
/// `videos`) for `listAssetSources` / `resolveSource` round-trips.
/// Cap 10/ADR-020: also constructs [AssetSourceKind.album] /
/// [AssetSourceKind.smartAlbum] references (id = Photos collection
/// `localIdentifier`). Resolve of non-built-in kinds is not Cap 10 work.
///
/// Wire mapping (when used): `sourceType` = [kind].name,
/// `sourceIdentifier` = [id].
class SourceReference {
  const SourceReference({required this.kind, required this.id});

  factory SourceReference.fromAssetSource(AssetSource source) {
    return SourceReference(kind: source.kind, id: source.id);
  }

  static const all = SourceReference(
    kind: AssetSourceKind.entireLibrary,
    id: 'all',
  );

  static const photos = SourceReference(
    kind: AssetSourceKind.mediaTypePhotos,
    id: 'photos',
  );

  static const videos = SourceReference(
    kind: AssetSourceKind.mediaTypeVideos,
    id: 'videos',
  );

  final AssetSourceKind kind;
  final String id;

  /// Whether this is one of the three Cap 6 legal built-in pairs.
  ///
  /// Album / Smart Album references are never built-in pairs.
  bool get isLegalBuiltInPair {
    return switch (kind) {
      AssetSourceKind.entireLibrary => id == 'all',
      AssetSourceKind.mediaTypePhotos => id == 'photos',
      AssetSourceKind.mediaTypeVideos => id == 'videos',
      AssetSourceKind.album || AssetSourceKind.smartAlbum => false,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SourceReference && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);
}
