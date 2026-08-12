import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_attempt.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

/// Sequential Live Binding resolution of a [SourcePoolDefinition] (ADR-021).
///
/// Calls [resolveOne] **one source at a time** in Definition order, then
/// incrementally coalesces by first appearance. Peak memory: one in-flight
/// id list + growing coalesced accumulator + seen-id set.
///
/// Partial Empty / Unavailable / Unauthorized is non-blocking (Glossary §16).
/// Unexpected errors from [resolveOne] propagate (not mapped to unavailable).
Future<ResolvedPoolSnapshot> resolvePool({
  required SourcePoolDefinition definition,
  required Future<SourceResolveAttempt> Function(SourceReference) resolveOne,
}) async {
  final coalesced = <String>[];
  final seen = <String>{};
  final statuses = <SourceResolveStatus>[];

  for (final ref in definition.orderedSourceReferences) {
    final attempt = await resolveOne(ref);
    switch (attempt) {
      case SourceResolveSuccess(:final assetIdentifiers):
        var contributed = 0;
        for (final id in assetIdentifiers) {
          if (seen.add(id)) {
            coalesced.add(id);
            contributed += 1;
          }
        }
        statuses.add(
          SourceResolveStatus(
            reference: ref,
            availability: assetIdentifiers.isEmpty
                ? AssetSourceAvailability.empty
                : AssetSourceAvailability.available,
            rawCount: assetIdentifiers.length,
            contributedCount: contributed,
          ),
        );
      case SourceResolveFailed(:final availability):
        statuses.add(
          SourceResolveStatus(
            reference: ref,
            availability: availability,
            rawCount: 0,
            contributedCount: 0,
          ),
        );
    }
  }

  return ResolvedPoolSnapshot(
    id: definition.id,
    coalescedAssetIds: coalesced,
    sourceStatuses: statuses,
  );
}
