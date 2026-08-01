/// Per-type library counts for the authorized Photos set (Cap 5.4).
///
/// [photos] includes still images and Live Photos; [all] = photos + videos.
class LibraryTotals {
  const LibraryTotals({
    required this.all,
    required this.photos,
    required this.videos,
  });

  final int all;
  final int photos;
  final int videos;
}
