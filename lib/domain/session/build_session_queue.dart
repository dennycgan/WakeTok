import 'dart:math';

import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';

/// Max Fisher–Yates retries when avoiding [previousRoundLastId] as the new
/// round's first id (ADR-023 D5; Glossary best-effort first≠last).
const int kShuffleFirstLastAvoidMaxAttempts = 32;

/// Builds a finite [SessionQueue] from a Snapshot + Configuration
/// (ADR-022 Sequential; ADR-023 Endless Shuffle).
///
/// **Sequential:** `orderedAssetIds` follows [workingAssetIds] when set,
/// otherwise `snapshot.coalescedAssetIds` (no re-sort; ADR-022 D4/D5).
///
/// **Shuffle (ADR-023 D4/D5):** Fisher–Yates over the working id list (or
/// full Snapshot when [workingAssetIds] is omitted). No Eligibility.
/// [random] defaults to [Random] when omitted. Retries (same [Random]
/// instance) when [previousRoundLastId] is set, `n > 1`, and the shuffle
/// would start with that id. Cap [kShuffleFirstLastAvoidMaxAttempts]; if
/// still colliding, accept the last attempt (including n=2 pools where
/// first≠last is often unsatisfiable — never spins forever).
///
/// Cap 24.4b: mid-session rebuilds pass [workingAssetIds] =
/// [sessionWorkingAssetIds] so soft-deleted ids stay out of the Queue.
/// New Sessions omit it (full Snapshot).
///
/// Advance Mode and Repeat Policy are stored on the queue but do not change
/// the id list within a round. Round boundary reshuffle is a new call with
/// [previousRoundLastId] set.
SessionQueue buildSessionQueue({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
  Random? random,
  String? previousRoundLastId,
  List<String>? workingAssetIds,
}) {
  final source = workingAssetIds ?? snapshot.coalescedAssetIds;
  switch (configuration.orderPolicy) {
    case OrderPolicy.sequential:
      return SessionQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        orderedAssetIds: List<String>.from(source),
      );
    case OrderPolicy.shuffle:
      return _buildShuffleQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        source: source,
        random: random ?? Random(),
        previousRoundLastId: previousRoundLastId,
      );
  }
}

SessionQueue _buildShuffleQueue({
  required String snapshotId,
  required SessionConfiguration configuration,
  required List<String> source,
  required Random random,
  required String? previousRoundLastId,
}) {
  final n = source.length;
  final avoidFirst = previousRoundLastId != null && n > 1;

  var ordered = _fisherYates(source, random);
  if (avoidFirst) {
    var attempts = 1;
    while (ordered.isNotEmpty &&
        ordered.first == previousRoundLastId &&
        attempts < kShuffleFirstLastAvoidMaxAttempts) {
      ordered = _fisherYates(source, random);
      attempts++;
    }
  }

  return SessionQueue(
    snapshotId: snapshotId,
    configuration: configuration,
    orderedAssetIds: ordered,
  );
}

/// In-place Fisher–Yates on a copy of [source], using [random].
List<String> _fisherYates(List<String> source, Random random) {
  final list = List<String>.from(source);
  for (var i = list.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}
