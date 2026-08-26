import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';

/// Fast Presentation Metadata fields for Overlay rows 1–3 (Cap 8.3 / ADR-015).
///
/// File size is requested separately via [PresentationFileSize].
class PresentationMetadata {
  const PresentationMetadata({
    required this.assetIdentifier,
    required this.mediaKind,
    this.createdAt,
  });

  final String assetIdentifier;
  final PresentationMediaKind mediaKind;

  /// PhotoKit `creationDate`; null when the system value is nil (no epoch).
  final DateTime? createdAt;
}

/// Optional file size for Overlay row 3 (POC-10 Tier 3/4).
///
/// Null [fileSizeBytes] means blank UI content — never treat as zero bytes.
class PresentationFileSize {
  const PresentationFileSize({
    required this.assetIdentifier,
    this.fileSizeBytes,
    this.fileSizeSemantics,
  });

  final String assetIdentifier;
  final int? fileSizeBytes;
  final FileSizeSemantics? fileSizeSemantics;
}
