import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_media_kind.dart';

/// One PHAsset-level catalog row (id / type / creation date / availability).
class LibraryAsset {
  const LibraryAsset({
    required this.id,
    required this.kind,
    required this.availability,
    this.createdAt,
  });

  final String id;
  final LibraryMediaKind kind;
  final AssetAvailability availability;

  /// PhotoKit `creationDate`; null when the system value is nil (no epoch).
  final DateTime? createdAt;
}
