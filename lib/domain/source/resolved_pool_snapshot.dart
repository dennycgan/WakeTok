import 'package:waketok/domain/source/source_resolve_status.dart';

/// Runtime coalesced view of a Source Pool Definition (Glossary §7–8 / ADR-021).
///
/// Not user-saveable (ADR-H). No Media Item count hard cap (ADR-P).
/// Must not retain per-source raw identifier lists.
class ResolvedPoolSnapshot {
  ResolvedPoolSnapshot({
    required this.id,
    required List<String> coalescedAssetIds,
    required List<SourceResolveStatus> sourceStatuses,
  })  : coalescedAssetIds = List<String>.unmodifiable(coalescedAssetIds),
        sourceStatuses = List<SourceResolveStatus>.unmodifiable(sourceStatuses);

  /// Echo of the SourcePoolDefinition id that produced this snapshot.
  final String id;

  /// Ordered, first-appearance-coalesced asset identifiers.
  final List<String> coalescedAssetIds;

  /// One row per Definition source, same order as the recipe.
  final List<SourceResolveStatus> sourceStatuses;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! ResolvedPoolSnapshot) {
      return false;
    }
    if (id != other.id) {
      return false;
    }
    if (coalescedAssetIds.length != other.coalescedAssetIds.length ||
        sourceStatuses.length != other.sourceStatuses.length) {
      return false;
    }
    for (var i = 0; i < coalescedAssetIds.length; i++) {
      if (coalescedAssetIds[i] != other.coalescedAssetIds[i]) {
        return false;
      }
    }
    for (var i = 0; i < sourceStatuses.length; i++) {
      if (sourceStatuses[i] != other.sourceStatuses[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        Object.hashAll(coalescedAssetIds),
        Object.hashAll(sourceStatuses),
      );
}
