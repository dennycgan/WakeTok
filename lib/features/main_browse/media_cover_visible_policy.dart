/// Cap 26.4c / ADR-054: whether the current page has painted a real media
/// cover the user can see (orthogonal to [mainBrowseCurrentAssetActionableProvider]).
///
/// Pure predicate — no Riverpod. [MediaFeedPage] publishes the result to
/// `mainBrowseCurrentAssetMediaCoverVisibleProvider`.
bool mediaCoverVisiblePredicate({
  required bool loading,
  required bool liveMotionMounted,
  required bool hasDisplay,
  required bool stillCoverReady,
  required bool stillCoverDecodeBroken,
  required bool isVideo,
  required bool surfaceReady,
}) {
  if (loading) {
    return false;
  }
  if (liveMotionMounted) {
    return true;
  }
  if (hasDisplay) {
    return stillCoverReady && !stillCoverDecodeBroken;
  }
  if (isVideo) {
    return surfaceReady;
  }
  return false;
}
