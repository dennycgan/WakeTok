import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Per-source row on a [ResolvedPoolSnapshot] (ADR-021).
///
/// Counts only — never retains the source's full id list.
class SourceResolveStatus {
  const SourceResolveStatus({
    required this.reference,
    required this.availability,
    required this.rawCount,
    required this.contributedCount,
  });

  final SourceReference reference;
  final AssetSourceAvailability availability;

  /// Ids returned by this source before coalescing (0 if failed).
  final int rawCount;

  /// Ids from this source that entered the coalesced snapshot (new ids).
  final int contributedCount;

  @override
  bool operator ==(Object other) {
    return other is SourceResolveStatus &&
        other.reference == reference &&
        other.availability == availability &&
        other.rawCount == rawCount &&
        other.contributedCount == contributedCount;
  }

  @override
  int get hashCode => Object.hash(
        reference,
        availability,
        rawCount,
        contributedCount,
      );
}
