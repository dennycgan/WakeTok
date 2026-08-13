import 'dart:math';

import 'package:waketok/domain/session/build_session_queue.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';

/// In-memory Consumption Session for Cap 13 Continuity / Stability
/// (ADR-023 D2/D7; Glossary §12 slim subset).
///
/// Holds a frozen [ResolvedPoolSnapshot], the current finite [SessionQueue],
/// browse index, and optional playback position. **No** Runtime Presentation
/// fields, **no** SessionCheckpoint persistence, **no** browse-history list
/// (Cap 13.3 Q4=A), **no** library-refresh API (Queue Stability is passive —
/// ADR-023 D7).
class ConsumptionSession {
  ConsumptionSession({
    required this.snapshot,
    required this.queue,
    required this.currentIndex,
    this.playbackPositionMs,
  }) {
    final n = queue.orderedAssetIds.length;
    if (n == 0) {
      if (currentIndex != 0) {
        throw ArgumentError.value(
          currentIndex,
          'currentIndex',
          'must be 0 when the queue is empty',
        );
      }
    } else if (currentIndex < 0 || currentIndex >= n) {
      throw ArgumentError.value(
        currentIndex,
        'currentIndex',
        'must be in 0..${n - 1} for queue length $n',
      );
    }
  }

  /// Snapshot frozen for this session (ADR-I / ADR-023 D7).
  final ResolvedPoolSnapshot snapshot;

  /// Current finite Session Queue (one Sequential list or one Shuffle round).
  final SessionQueue queue;

  /// Index into [SessionQueue.orderedAssetIds].
  final int currentIndex;

  /// Optional playback position in milliseconds (ADR-023 D2).
  final int? playbackPositionMs;

  /// Current asset id, or `null` when the queue is empty.
  String? get currentAssetId {
    final ids = queue.orderedAssetIds;
    if (ids.isEmpty) {
      return null;
    }
    return ids[currentIndex];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ConsumptionSession &&
        snapshot == other.snapshot &&
        queue == other.queue &&
        currentIndex == other.currentIndex &&
        playbackPositionMs == other.playbackPositionMs;
  }

  @override
  int get hashCode => Object.hash(
        snapshot,
        queue,
        currentIndex,
        playbackPositionMs,
      );
}

/// Starts an in-memory session: builds a [SessionQueue] from [snapshot] +
/// [configuration], clamps [initialIndex], stores optional playback position.
ConsumptionSession startConsumptionSession({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
  Random? random,
  int initialIndex = 0,
  int? playbackPositionMs,
}) {
  final queue = buildSessionQueue(
    snapshot: snapshot,
    configuration: configuration,
    random: random,
  );
  final n = queue.orderedAssetIds.length;
  final index = n == 0 ? 0 : initialIndex.clamp(0, n - 1);
  return ConsumptionSession(
    snapshot: snapshot,
    queue: queue,
    currentIndex: index,
    playbackPositionMs: playbackPositionMs,
  );
}

/// Applies a new [SessionConfiguration] on the **same** Snapshot.
///
/// Rebuild of `orderedAssetIds` runs only when [OrderPolicy] changes
/// (ADR-I / Rule I: changes that affect **order**). `advanceMode` /
/// `repeatPolicy` updates replace configuration only — they do not
/// re-permute ids.
///
/// Kickoff SPD rule §9 lists Order/Advance/Repeat changes together as
/// configuration the App "may regenerate or adjust the Session Queue" for
/// — it does not itself distinguish which axis rebuilds the permutation.
/// That distinction is this Cap's design choice, grounded in Glossary §11
/// (finite queue; infinite looping is controlled by Repeat Policy, not by
/// reconstructing the queue).
///
/// Continuity (ADR-023 Cap 13 subset): when Order rebuilds, the current
/// asset id is remapped into the new queue when present; playback position
/// is preserved. Does not implement Manual↔Auto Eligibility mapping or
/// cross-tab Continuity.
ConsumptionSession applySessionConfiguration({
  required ConsumptionSession session,
  required SessionConfiguration newConfiguration,
  Random? random,
}) {
  final oldConfig = session.queue.configuration;
  if (newConfiguration == oldConfig) {
    return session;
  }

  if (newConfiguration.orderPolicy == oldConfig.orderPolicy) {
    // Advance / Repeat only — adjust configuration, keep permutation.
    final sameIds = SessionQueue(
      snapshotId: session.queue.snapshotId,
      configuration: newConfiguration,
      orderedAssetIds: session.queue.orderedAssetIds,
    );
    return ConsumptionSession(
      snapshot: session.snapshot,
      queue: sameIds,
      currentIndex: session.currentIndex,
      playbackPositionMs: session.playbackPositionMs,
    );
  }

  // Order Policy changed — rebuild permutation on the same Snapshot.
  final newQueue = buildSessionQueue(
    snapshot: session.snapshot,
    configuration: newConfiguration,
    random: random,
  );
  final newIndex = _remapIndex(
    previousAssetId: session.currentAssetId,
    previousIndex: session.currentIndex,
    newOrderedIds: newQueue.orderedAssetIds,
  );
  return ConsumptionSession(
    snapshot: session.snapshot,
    queue: newQueue,
    currentIndex: newIndex,
    playbackPositionMs: session.playbackPositionMs,
  );
}

int _remapIndex({
  required String? previousAssetId,
  required int previousIndex,
  required List<String> newOrderedIds,
}) {
  final n = newOrderedIds.length;
  if (n == 0) {
    return 0;
  }
  if (previousAssetId != null) {
    final found = newOrderedIds.indexOf(previousAssetId);
    if (found >= 0) {
      return found;
    }
  }
  return previousIndex.clamp(0, n - 1);
}

/// Starts the next Endless Shuffle round on the **same** Snapshot (ADR-023).
///
/// When [RepeatPolicy.repeatAll] and the queue has more than one id, builds a
/// new Shuffle [SessionQueue] with [previousRoundLastId] = current round's
/// last id, and returns a session at index 0. Clears [playbackPositionMs]
/// (new round head).
///
/// No-ops (returns [session] unchanged) when:
/// - [repeatPolicy] is not [RepeatPolicy.repeatAll], or
/// - the queue length is ≤ 1 (nothing to reshuffle meaningfully).
ConsumptionSession startNextShuffleRound({
  required ConsumptionSession session,
  Random? random,
}) {
  final config = session.queue.configuration;
  if (config.repeatPolicy != RepeatPolicy.repeatAll) {
    return session;
  }
  final ids = session.queue.orderedAssetIds;
  if (ids.length <= 1) {
    return session;
  }
  final newQueue = buildSessionQueue(
    snapshot: session.snapshot,
    configuration: config,
    random: random,
    previousRoundLastId: ids.last,
  );
  return ConsumptionSession(
    snapshot: session.snapshot,
    queue: newQueue,
    currentIndex: 0,
    playbackPositionMs: null,
  );
}
