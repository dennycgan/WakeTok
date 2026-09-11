import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';

/// Cap 24.4c: process-lifetime soft-deleted asset ids (in-memory only).
///
/// Survives Consumption Session / Origin switches within one app process.
/// Cleared only when the process dies (force-quit) — never persisted.
/// Distinct from [sessionWorkingAssetIds] (per-Session Queue working set).
///
/// Used to filter coalesced ids when **starting** a Session from a cached
/// Snapshot without mutating [browseSnapshotCacheProvider] (Q4′=A).
final processSoftDeletedAssetIdsProvider = NotifierProvider<
    ProcessSoftDeletedAssetIds, Set<String>>(
  ProcessSoftDeletedAssetIds.new,
);

class ProcessSoftDeletedAssetIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Record a successful App soft-delete (Host success + Queue kick).
  void add(String assetId) {
    if (assetId.isEmpty || state.contains(assetId)) {
      return;
    }
    state = {...state, assetId};
  }

  /// Test / explicit reset only — production relies on process death.
  void clear() {
    if (state.isEmpty) {
      return;
    }
    state = const {};
  }
}

/// Returns [snapshot] unchanged, or a **new** Snapshot whose coalesced ids
/// omit [excluded]. Does **not** write back to the Snapshot cache.
ResolvedPoolSnapshot snapshotExcludingProcessSoftDeletes({
  required ResolvedPoolSnapshot snapshot,
  required Set<String> excluded,
}) {
  if (excluded.isEmpty) {
    return snapshot;
  }
  final nextIds = <String>[
    for (final id in snapshot.coalescedAssetIds)
      if (!excluded.contains(id)) id,
  ];
  if (nextIds.length == snapshot.coalescedAssetIds.length) {
    return snapshot;
  }
  final nextAvailability = <String, AssetAvailability>{
    for (final entry in snapshot.assetAvailabilityById.entries)
      if (!excluded.contains(entry.key)) entry.key: entry.value,
  };
  return ResolvedPoolSnapshot(
    id: snapshot.id,
    coalescedAssetIds: nextIds,
    sourceStatuses: snapshot.sourceStatuses,
    assetAvailabilityById: nextAvailability,
  );
}
