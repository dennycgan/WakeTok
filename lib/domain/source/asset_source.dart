import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

/// One listable Asset Source.
///
/// Cap 6 built-ins use frozen short ids and exact [estimatedCount].
/// Cap 10 may construct Album / Smart Album kinds on recipe references;
/// list/resolve of those kinds remains a later capability.
///
/// No [displayName] — product copy comes from ARB in UI (ADR-012 / ADR-013).
class AssetSource {
  const AssetSource({
    required this.kind,
    required this.id,
    required this.estimatedCount,
    required this.availability,
    required this.canAddContent,
  });

  final AssetSourceKind kind;

  /// Frozen short id: `all` / `photos` / `videos`.
  final String id;

  /// For built-ins: exact count matching the corresponding library totals.
  final int estimatedCount;

  final AssetSourceAvailability availability;

  /// Built-ins are never writable album targets.
  final bool canAddContent;
}
