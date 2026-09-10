import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/session_queue.dart';

/// Result of removing one asset id from an in-memory Session Queue (Cap 24.4).
class RemoveAssetFromSessionQueueResult {
  const RemoveAssetFromSessionQueueResult({
    required this.session,
    required this.feedIndex,
    required this.removed,
  });

  /// Same Snapshot / configuration; queue without [assetId] when [removed].
  final ConsumptionSession session;

  /// Browse playhead after the remove (pair with feed index notifier).
  final int feedIndex;

  /// False when [assetId] was not in the queue (no-op).
  final bool removed;
}

/// Cap 24.4 / ADR-050 D4: remove [assetId] from the Session Queue and land
/// the Browse playhead (explicit App action — not ADR-023 D7 library observer).
///
/// Landing (owner Q1=A / Q2=A):
/// - Delete at playhead, not last → keep [feedIndex] (former next rises).
/// - Delete at playhead, was last, queue still non-empty → `newLength - 1`.
/// - Empty queue → feedIndex `0`.
/// - Delete **before** playhead → playhead index shifts left by 1.
/// - Delete **after** playhead → feedIndex unchanged.
///
/// Does **not** reshuffle remaining ids (ADR-023 D5 mid-round stability).
RemoveAssetFromSessionQueueResult removeAssetFromSessionQueue({
  required ConsumptionSession session,
  required String assetId,
  required int feedIndex,
}) {
  final ids = session.queue.orderedAssetIds;
  final removeAt = ids.indexOf(assetId);
  if (removeAt < 0) {
    return RemoveAssetFromSessionQueueResult(
      session: session,
      feedIndex: _clampFeedIndex(feedIndex, ids.length),
      removed: false,
    );
  }

  final nextIds = List<String>.from(ids)..removeAt(removeAt);
  final nextQueue = SessionQueue(
    snapshotId: session.queue.snapshotId,
    configuration: session.queue.configuration,
    orderedAssetIds: nextIds,
  );

  final int nextFeed;
  if (nextIds.isEmpty) {
    nextFeed = 0;
  } else if (feedIndex > removeAt) {
    nextFeed = feedIndex - 1;
  } else if (feedIndex == removeAt) {
    // Current item removed: same index = former next, or previous if was last.
    nextFeed = feedIndex < nextIds.length ? feedIndex : nextIds.length - 1;
  } else {
    nextFeed = feedIndex;
  }

  final clamped = _clampFeedIndex(nextFeed, nextIds.length);
  final nextSession = ConsumptionSession(
    snapshot: session.snapshot,
    queue: nextQueue,
    currentIndex: clamped,
    playbackPositionMs: null,
  );
  return RemoveAssetFromSessionQueueResult(
    session: nextSession,
    feedIndex: clamped,
    removed: true,
  );
}

int _clampFeedIndex(int feedIndex, int queueLength) {
  if (queueLength <= 0) {
    return 0;
  }
  if (feedIndex < 0) {
    return 0;
  }
  if (feedIndex >= queueLength) {
    return queueLength - 1;
  }
  return feedIndex;
}
