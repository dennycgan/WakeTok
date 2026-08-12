import 'package:waketok/domain/source/asset_source_kind.dart';

/// Default item ordering for an Asset Source kind (kickoff ADR-M / ADR-021).
///
/// Slot only — not stored on SourcePoolDefinition or SourceReference.
/// Cap 11.3: Album / Smart Album use the same creation-date descending
/// policy as Cap 6 built-ins (ADR-021 D1=A).
enum ItemOrderingPolicy {
  /// Locked for Entire Library, Media Type, Album, and Smart Album Sources.
  creationDateDescending,

  /// Reserved for kinds without a locked Host ordering yet.
  unspecified;

  /// Maps [kind] to the default ordering policy (ADR-020 D9 / ADR-021 D1).
  static ItemOrderingPolicy forKind(AssetSourceKind kind) {
    return switch (kind) {
      AssetSourceKind.entireLibrary ||
      AssetSourceKind.mediaTypePhotos ||
      AssetSourceKind.mediaTypeVideos ||
      AssetSourceKind.album ||
      AssetSourceKind.smartAlbum =>
        ItemOrderingPolicy.creationDateDescending,
    };
  }
}
