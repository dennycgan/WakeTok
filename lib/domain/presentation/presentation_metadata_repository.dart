import 'package:waketok/domain/presentation/presentation_metadata.dart';

/// Cap 8.3 Presentation Metadata over PhotoLibraryApi (ADR-015).
///
/// Two calls so date/kind can arrive before file size. Cap 8.5 Overlay
/// consumers must discard stale in-flight results with the existing Main Browse
/// feed media request gate (same pattern as display/playable) — that wiring
/// lands with Overlay UI, not in this repository interface.
abstract class PresentationMetadataRepository {
  /// Basics: [PresentationMetadata.mediaKind] always set when the asset
  /// exists; [PresentationMetadata.createdAt] may be null.
  Future<PresentationMetadata> requestPresentationMetadata(
    String assetIdentifier,
  );

  /// Best-effort local size (Tier 3/4). Null bytes means blank — not zero.
  Future<PresentationFileSize> requestPresentationFileSize(
    String assetIdentifier,
  );
}
