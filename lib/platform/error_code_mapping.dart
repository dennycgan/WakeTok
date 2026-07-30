/// Maps wire [ErrorCode] / channel failures onto domain [AppError]
/// (ADR-008 wire half; lives under platform as protocol adapter — ADR-009).
library;

import 'package:flutter/services.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';

/// 1:1 mapping from Pigeon [ErrorCode] to [AppError].
///
/// Exhaustive on [ErrorCode]; adding a wire member without updating this
/// switch is a compile error.
AppError appErrorFromErrorCode(ErrorCode code) {
  switch (code) {
    case ErrorCode.unauthorized:
      return AppError.unauthorized;
    case ErrorCode.assetUnavailable:
      return AppError.assetUnavailable;
    case ErrorCode.iCloudDownloadRequired:
      return AppError.iCloudDownloadRequired;
    case ErrorCode.iCloudDownloadFailed:
      return AppError.iCloudDownloadFailed;
    case ErrorCode.unsupportedMedia:
      return AppError.unsupportedMedia;
    case ErrorCode.noPlayableAudioTrack:
      return AppError.noPlayableAudioTrack;
    case ErrorCode.insufficientStorage:
      return AppError.insufficientStorage;
    case ErrorCode.exportFailed:
      return AppError.exportFailed;
    case ErrorCode.photosImportFailed:
      return AppError.photosImportFailed;
    case ErrorCode.albumUnavailable:
      return AppError.albumUnavailable;
    case ErrorCode.albumNotWritable:
      return AppError.albumNotWritable;
    case ErrorCode.operationCancelled:
      return AppError.operationCancelled;
    case ErrorCode.unknown:
      return AppError.unknown;
  }
}

/// Parses [PlatformException.code] as [ErrorCode]; R5 → [AppError.unknown].
AppError appErrorFromPlatformException(PlatformException exception) {
  final raw = exception.code;
  if (raw.isEmpty) {
    return AppError.unknown;
  }
  for (final code in ErrorCode.values) {
    if (code.name == raw) {
      return appErrorFromErrorCode(code);
    }
  }
  return AppError.unknown;
}
