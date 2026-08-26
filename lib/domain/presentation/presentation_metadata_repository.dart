import 'package:waketok/domain/presentation/presentation_metadata.dart';

/// Cap 8.3 Presentation Metadata over PhotoLibraryApi (ADR-015).
///
/// Basics and file size are separate so date/kind can arrive before size.
/// Cap 17.7 adds [requestCaptureWallClock] for Overlay exact (ADR-038).
/// Cap 8.5 Overlay consumers must discard stale in-flight results with the
/// existing Main Browse feed media request gate (same pattern as
/// display/playable) — that wiring lands with Overlay UI, not in this
/// repository interface.
abstract class PresentationMetadataRepository {
  /// Basics: [PresentationMetadata.mediaKind] always set when the asset
  /// exists; [PresentationMetadata.createdAt] may be null.
  Future<PresentationMetadata> requestPresentationMetadata(
    String assetIdentifier,
  );

  /// Cap 17.7: Photos-aligned capture wall clock, or null when unavailable
  /// (no EXIF/TIFF, video this phase, iCloud-only without local bytes).
  Future<CaptureWallClock?> requestCaptureWallClock(String assetIdentifier);

  /// Best-effort local size (Tier 3/4). Null bytes means blank — not zero.
  Future<PresentationFileSize> requestPresentationFileSize(
    String assetIdentifier,
  );
}
