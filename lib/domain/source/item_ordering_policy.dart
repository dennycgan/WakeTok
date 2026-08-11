import 'package:waketok/domain/source/asset_source_kind.dart';

/// Default item ordering for an Asset Source kind (kickoff ADR-M / ADR-020).
///
/// Slot only in Cap 10 — not stored on SourcePoolDefinition or
/// SourceReference. Album / Smart Album stay [unspecified] until a later
/// capability closes the ADR-M Open Question.
enum ItemOrderingPolicy {
  /// Locked for Entire Library + Media Type Sources (ADR-013).
  creationDateDescending,

  /// Deferred for Album / Smart Album (ADR-M Open Question).
  unspecified;

  /// Maps [kind] to the Cap 10 default ordering policy (D9=A).
  static ItemOrderingPolicy forKind(AssetSourceKind kind) {
    return switch (kind) {
      AssetSourceKind.entireLibrary ||
      AssetSourceKind.mediaTypePhotos ||
      AssetSourceKind.mediaTypeVideos =>
        ItemOrderingPolicy.creationDateDescending,
      AssetSourceKind.album || AssetSourceKind.smartAlbum =>
        ItemOrderingPolicy.unspecified,
    };
  }
}
