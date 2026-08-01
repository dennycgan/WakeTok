/// Media classification for library catalog rows (Cap 5.4).
///
/// Independent of Pigeon [MediaKind]; gateway maps at the platform boundary.
enum LibraryMediaKind {
  image,
  video,
  livePhoto,
  unknown,
}

extension LibraryMediaKindCounts on LibraryMediaKind {
  /// Photos row in library totals: still image + Live Photo (decision 3A).
  bool get countsAsPhoto =>
      this == LibraryMediaKind.image || this == LibraryMediaKind.livePhoto;

  bool get countsAsVideo => this == LibraryMediaKind.video;
}
