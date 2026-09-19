import 'dart:math';

import 'package:waketok/domain/session/all_rank_order.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';

/// Max Fisher–Yates retries when avoiding [previousRoundLastId] as the new
/// round's first id (ADR-023 D5; Glossary best-effort first≠last).
const int kShuffleFirstLastAvoidMaxAttempts = 32;

/// Builds a finite [SessionQueue] from a Snapshot + Configuration
/// (ADR-022 / ADR-023 / ADR-056).
///
/// **newestFirst (single-source):** `orderedAssetIds` follows
/// [workingAssetIds] when set, otherwise `snapshot.coalescedAssetIds`
/// (former `sequential`).
///
/// **newestFirst (multi-source):** when [allRanks] is non-null, sort working
/// ids by All rank (ADR-056 D4). When [allRanks] is null, fall back to
/// coalesced / working order (caller should supply ranks for multi-source).
///
/// **oldestFirst:** reverse of the newestFirst list (ADR-056 D2).
///
/// **Shuffle (ADR-023 D4/D5):** Fisher–Yates over the working id list.
///
/// Cap 24.4b: mid-session rebuilds pass [workingAssetIds] =
/// [sessionWorkingAssetIds] so soft-deleted ids stay out of the Queue.
SessionQueue buildSessionQueue({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
  Random? random,
  String? previousRoundLastId,
  List<String>? workingAssetIds,
  Map<String, int>? allRanks,
}) {
  final source = workingAssetIds ?? snapshot.coalescedAssetIds;
  switch (configuration.orderPolicy) {
    case OrderPolicy.newestFirst:
      final ordered = _newestFirstOrdered(
        source: source,
        allRanks: allRanks,
      );
      return SessionQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        orderedAssetIds: ordered,
      );
    case OrderPolicy.oldestFirst:
      final newest = _newestFirstOrdered(
        source: source,
        allRanks: allRanks,
      );
      return SessionQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        orderedAssetIds: newest.reversed.toList(),
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

List<String> _newestFirstOrdered({
  required List<String> source,
  required Map<String, int>? allRanks,
}) {
  if (allRanks == null || allRanks.isEmpty) {
    return List<String>.from(source);
  }
  return sortWorkingNewestFirstByAllRank(
    workingIds: source,
    allRanks: allRanks,
  );
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
