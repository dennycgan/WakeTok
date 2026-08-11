/// Asset Source kinds available in the domain model (Cap 10 / ADR-020).
///
/// Cap 6 built-ins: [entireLibrary], [mediaTypePhotos], [mediaTypeVideos].
/// Cap 10 adds [album] and [smartAlbum] for Source Pool recipe references.
/// Wire `other` stays out of domain (D8=A). Gateway mapping of non-built-in
/// wire kinds still throws until a later Cap opens list/resolve (D7=A).
enum AssetSourceKind {
  entireLibrary,
  mediaTypePhotos,
  mediaTypeVideos,
  album,
  smartAlbum,
}
