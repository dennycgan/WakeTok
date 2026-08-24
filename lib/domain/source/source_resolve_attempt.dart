import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';

/// Outcome of one Asset Source resolve for pool orchestration (ADR-021).
///
/// Domain-only: callers map Host / channel errors into this type
/// outside `lib/domain/` (Cap 11.5). Empty success is Empty availability,
/// not a failure — Glossary §16.
sealed class SourceResolveAttempt {
  const SourceResolveAttempt();
}

/// Host returned an ordered id list (may be empty → Empty availability).
final class SourceResolveSuccess extends SourceResolveAttempt {
  SourceResolveSuccess(
    List<String> assetIdentifiers, {
    Map<String, AssetAvailability> assetAvailabilityById = const {},
  })  : assetIdentifiers = List<String>.unmodifiable(assetIdentifiers),
        assetAvailabilityById =
            Map<String, AssetAvailability>.unmodifiable(assetAvailabilityById);

  final List<String> assetIdentifiers;

  /// Parallel list-time availability from resolve (Cap 15.12).
  final Map<String, AssetAvailability> assetAvailabilityById;
}

/// Host could not enumerate members. [availability] is only
/// [AssetSourceAvailability.unauthorized] or
/// [AssetSourceAvailability.unavailable].
final class SourceResolveFailed extends SourceResolveAttempt {
  SourceResolveFailed(this.availability) {
    if (availability != AssetSourceAvailability.unauthorized &&
        availability != AssetSourceAvailability.unavailable) {
      throw ArgumentError.value(
        availability,
        'availability',
        'Failed attempt must be unauthorized or unavailable',
      );
    }
  }

  final AssetSourceAvailability availability;
}
