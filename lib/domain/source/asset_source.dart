import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

/// One listable Asset Source.
///
/// Cap 6 built-ins use frozen short ids and exact [estimatedCount].
/// Cap 11.2 lists User / Smart Albums: [id] is Photos
/// `localIdentifier`; [displayName] is the Photos title (built-ins keep
/// `""` — product labels stay in ARB).
///
/// [estimatedCount] may be null for albums when PhotoKit reports
/// `NSNotFound` (unknown — must not be treated as empty).
///
/// Cap 21.4b: [collectionSubtype] is PhotoKit smart-album subtype raw value
/// when [kind] is [AssetSourceKind.smartAlbum]; otherwise null. Build catalog
/// labels use ARB keyed by subtype (not [displayName]).
class AssetSource {
  const AssetSource({
    required this.kind,
    required this.id,
    required this.displayName,
    required this.estimatedCount,
    required this.availability,
    required this.canAddContent,
    this.collectionSubtype,
  });

  final AssetSourceKind kind;

  /// Built-ins: `all` / `photos` / `videos`. Albums: collection local id.
  final String id;

  /// Photos `localizedTitle` for albums; empty for built-ins (ARB in UI).
  final String displayName;

  /// Built-ins: exact count. Albums: approximate, or null if unknown.
  final int? estimatedCount;

  final AssetSourceAvailability availability;

  /// Built-ins and Cap 11.2 albums: false (Add to Album Cap later).
  final bool canAddContent;

  /// Cap 21.4b smart albums only — `PHAssetCollectionSubtype.rawValue`.
  final int? collectionSubtype;
}
