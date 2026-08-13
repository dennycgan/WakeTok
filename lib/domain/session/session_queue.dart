import 'package:waketok/domain/session/session_configuration.dart';

/// Finite ordered Media Item list for one Consumption Session
/// (Glossary §11 / ADR-022 / ADR-023).
///
/// Sequential construction copies [ResolvedPoolSnapshot.coalescedAssetIds]
/// — no Queue-layer segmentIndex sort (ADR-022 D5). Shuffle construction is
/// one Endless Shuffle **round** (ADR-023 D5) — not an infinite list; the
/// next round is a new [buildSessionQueue] call. Repeat Policy is not
/// expanded into an infinite list.
class SessionQueue {
  SessionQueue({
    required this.snapshotId,
    required this.configuration,
    required List<String> orderedAssetIds,
  }) : orderedAssetIds = List<String>.unmodifiable(orderedAssetIds);

  /// Echo of [ResolvedPoolSnapshot.id] used to build this queue.
  final String snapshotId;

  /// Session Configuration that drove construction (Order / Advance / Repeat).
  final SessionConfiguration configuration;

  /// Finite ordered asset identifiers (one Sequential list or one Shuffle
  /// round).
  final List<String> orderedAssetIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SessionQueue) {
      return false;
    }
    if (snapshotId != other.snapshotId ||
        configuration != other.configuration) {
      return false;
    }
    // Element-wise — same discipline as ResolvedPoolSnapshot.coalescedAssetIds
    // (Dart List.== is identity, not deep equality).
    if (orderedAssetIds.length != other.orderedAssetIds.length) {
      return false;
    }
    for (var i = 0; i < orderedAssetIds.length; i++) {
      if (orderedAssetIds[i] != other.orderedAssetIds[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        snapshotId,
        configuration,
        Object.hashAll(orderedAssetIds),
      );
}
