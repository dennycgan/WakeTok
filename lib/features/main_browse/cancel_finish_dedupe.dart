// Cap 17.3 / ADR-034 Decision 8 — cancel finish id+window dedupe for 17.5.
//
// Host may emit leave_cancel and a late load-finished cancel for the same
// asset in one leave window (17.1 Full: raw cancel > leave count). Before/after
// metrics must count **deduped** cancel events, not raw finishes.

/// One Host cancel-finish observation (id + leave window).
class CancelFinishEvent {
  const CancelFinishEvent({
    required this.assetId,
    required this.windowId,
  });

  final String assetId;

  /// Opaque leave-window token (e.g. generation or leave sequence).
  final String windowId;

  @override
  bool operator ==(Object other) {
    return other is CancelFinishEvent &&
        other.assetId == assetId &&
        other.windowId == windowId;
  }

  @override
  int get hashCode => Object.hash(assetId, windowId);
}

/// Counts unique (assetId, windowId) pairs; duplicate finishes in the same
/// window collapse to one.
int dedupeCancelFinishCount(Iterable<CancelFinishEvent> events) {
  return events.toSet().length;
}
