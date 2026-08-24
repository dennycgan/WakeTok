import 'package:flutter/services.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_attempt.dart';

/// Maps [AssetSourceRepository.resolve] onto [SourceResolveAttempt] (Cap 11.5).
///
/// Lives in smoke/composition — not domain (ADR-021). Features must not import
/// `lib/platform/`; [PlatformException.code] is compared to [AppError] names.
Future<SourceResolveAttempt> resolveOneFromRepository(
  AssetSourceRepository repository,
  SourceReference reference,
) async {
  try {
    final resolved = await repository.resolve(reference);
    return sourceResolveAttemptFromResolved(resolved);
  } on PlatformException catch (exception) {
    final mapped = sourceResolveAttemptFromPlatformException(exception);
    if (mapped != null) {
      return mapped;
    }
    rethrow;
  }
}

SourceResolveAttempt sourceResolveAttemptFromResolved(ResolvedSource resolved) {
  return SourceResolveSuccess(
    resolved.assetIdentifiers,
    assetAvailabilityById: resolved.assetAvailabilityById,
  );
}

/// Maps expected Live Binding failures. Returns null when the caller must
/// rethrow (illegal pair, unknown, and any other channel error).
SourceResolveAttempt? sourceResolveAttemptFromPlatformException(
  PlatformException exception,
) {
  if (exception.code == AppError.unauthorized.name) {
    return SourceResolveFailed(AssetSourceAvailability.unauthorized);
  }
  if (exception.code == AppError.albumUnavailable.name) {
    return SourceResolveFailed(AssetSourceAvailability.unavailable);
  }
  return null;
}
