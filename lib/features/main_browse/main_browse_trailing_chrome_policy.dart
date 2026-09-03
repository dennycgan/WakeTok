/// Cap 19 / ADR-042 Decision 8: when trailing current-asset mutation chrome
/// (entry icon, future share, same slot family) is interaction-ready.
///
/// Distinct from Decision 7 (not-actionable → visible + dim). Callers that
/// own the slot must fully hide while peeking or covering; this predicate is
/// the three-axis gate for enablement.
bool mainBrowseTrailingMutationChromeVisible({
  required bool actionable,
  required bool verticalFeedSettled,
  required bool transitionCovering,
}) {
  return actionable && verticalFeedSettled && !transitionCovering;
}
