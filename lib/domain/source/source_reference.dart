import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

/// Reference passed to [AssetSourceRepository.resolve] (ADR-013 Option A).
///
/// Wire mapping: `sourceType` = [kind].name, `sourceIdentifier` = [id].
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
  bool get isLegalBuiltInPair {
    return switch (kind) {
      AssetSourceKind.entireLibrary => id == 'all',
      AssetSourceKind.mediaTypePhotos => id == 'photos',
      AssetSourceKind.mediaTypeVideos => id == 'videos',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SourceReference && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);
}
