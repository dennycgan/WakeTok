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
/// **Sequential:** `orderedAssetIds == snapshot.coalescedAssetIds` (no
/// re-sort; no segmentIndex Queue-layer step — ADR-022 D4/D5).
///
/// **Shuffle (ADR-023 D4/D5):** Fisher–Yates over the full Snapshot id
/// list (no Eligibility). [random] defaults to [Random] when omitted.
/// Retries (advancing the **same** [Random] instance — do not re-seed per
/// attempt) when [previousRoundLastId] is set, `n > 1`, and the shuffle
/// would start with that id. Cap [kShuffleFirstLastAvoidMaxAttempts]; if
/// still colliding, accept the last attempt.
///
/// Advance Mode and Repeat Policy are stored on the queue but do not change
/// the id list within a round (Glossary §11: Queue stays finite). Round
/// boundary reshuffle is a new call with [previousRoundLastId] set.
SessionQueue buildSessionQueue({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
  Random? random,
  String? previousRoundLastId,
}) {
  switch (configuration.orderPolicy) {
    case OrderPolicy.sequential:
      return SessionQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        orderedAssetIds: snapshot.coalescedAssetIds,
      );
    case OrderPolicy.shuffle:
      return _buildShuffleQueue(
        snapshot: snapshot,
        configuration: configuration,
        random: random ?? Random(),
        previousRoundLastId: previousRoundLastId,
      );
  }
}

SessionQueue _buildShuffleQueue({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
  required Random random,
  required String? previousRoundLastId,
}) {
  final source = snapshot.coalescedAssetIds;
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
    snapshotId: snapshot.id,
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
