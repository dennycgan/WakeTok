import 'package:waketok/domain/library/asset_availability.dart';

/// Result of resolving an Asset Source to ordered asset identifiers (D1=A).
class ResolvedSource {
  ResolvedSource({
    required this.sourceId,
    required List<String> assetIdentifiers,
    Map<String, AssetAvailability>? assetAvailabilityById,
  })  : assetIdentifiers = List<String>.unmodifiable(assetIdentifiers),
        assetAvailabilityById = Map<String, AssetAvailability>.unmodifiable(
          assetAvailabilityById ?? const {},
        );

  /// Echo of the resolved source id (built-in short id or album local id).
  final String sourceId;

  /// Full ordered list (creationDate descending on host). May be large (~40k).
  final List<String> assetIdentifiers;

  /// List-time availability from Host resolve (Cap 15.12 / KVC re-board).
  final Map<String, AssetAvailability> assetAvailabilityById;
}
