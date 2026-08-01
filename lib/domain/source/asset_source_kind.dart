/// Built-in Asset Source kinds only (Cap 6 / ADR-013).
///
/// Album / Smart Album / other kinds stay on the wire enum until a later
/// capability; Cap 6 mapping must not silently coerce them into these values.
enum AssetSourceKind {
  entireLibrary,
  mediaTypePhotos,
  mediaTypeVideos,
}
