import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';

/// Session-scoped Overlay field snapshot (ADR-015 Decision 3).
class PresentationOverlaySnapshot {
  const PresentationOverlaySnapshot({
    required this.assetIdentifier,
    this.createdAt,
    this.mediaKind,
    this.fileSizeBytes,
    this.fileSizeSemantics,
    this.locationLabel,
    this.captureWallClock,
    this.exactDateResolved = false,
  });

  final String assetIdentifier;
  final DateTime? createdAt;
  final PresentationMediaKind? mediaKind;
  final int? fileSizeBytes;
  final FileSizeSemantics? fileSizeSemantics;

  /// Resolved place name for Overlay row 4; null/empty collapses the row.
  /// Cap 8 never fills this (Q1=B); field exists so layout can stay Photo-App-A-aligned.
  final String? locationLabel;

  /// Cap 17.7: EXIF/TIFF naked wall clock when Host provided one.
  final CaptureWallClock? captureWallClock;

  /// Cap 17.7: true after Host [requestCaptureWallClock] completed (wall
  /// components, explicit nil, or mapped error→nil). Overlay rows 1–2 stay
  /// blank until this is true (bound reveal); row 3 size is independent.
  final bool exactDateResolved;

  PresentationOverlaySnapshot mergeBasics(PresentationMetadata meta) {
    final same = assetIdentifier == meta.assetIdentifier;
    return PresentationOverlaySnapshot(
      assetIdentifier: meta.assetIdentifier,
      createdAt: meta.createdAt,
      mediaKind: meta.mediaKind,
      fileSizeBytes: fileSizeBytes,
      fileSizeSemantics: fileSizeSemantics,
      locationLabel: locationLabel,
      // Preserve session wall-clock resolution across basics refresh.
      captureWallClock: same ? captureWallClock : null,
      exactDateResolved: same ? exactDateResolved : false,
    );
  }

  PresentationOverlaySnapshot mergeCaptureWallClock({
    required CaptureWallClock? wallClock,
  }) {
    return PresentationOverlaySnapshot(
      assetIdentifier: assetIdentifier,
      createdAt: createdAt,
      mediaKind: mediaKind,
      fileSizeBytes: fileSizeBytes,
      fileSizeSemantics: fileSizeSemantics,
      locationLabel: locationLabel,
      captureWallClock: wallClock,
      exactDateResolved: true,
    );
  }

  PresentationOverlaySnapshot mergeSize(PresentationFileSize size) {
    // Same metadata generation can complete two size requests out of order
    // (activation nil after Layer-2 refresh). isCurrent cannot drop the nil.
    final keepExisting = fileSizeBytes != null && size.fileSizeBytes == null;
    return PresentationOverlaySnapshot(
      assetIdentifier: assetIdentifier,
      createdAt: createdAt,
      mediaKind: mediaKind,
      fileSizeBytes: keepExisting ? fileSizeBytes : size.fileSizeBytes,
      fileSizeSemantics: keepExisting
          ? fileSizeSemantics
          : size.fileSizeSemantics,
      locationLabel: locationLabel,
      captureWallClock: captureWallClock,
      exactDateResolved: exactDateResolved,
    );
  }
}
