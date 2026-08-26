import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';

/// Naked capture wall clock (y/m/d/H/m) for Overlay exact row (Cap 17.7).
///
/// Not a [DateTime] — avoids accidental timezone conversion. Host fills from
/// EXIF `DateTimeOriginal` or TIFF `DateTime` when locally available.
class CaptureWallClock {
  const CaptureWallClock({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
}

/// Fast Presentation Metadata fields for Overlay rows 1–3 (Cap 8.3 / ADR-015).
///
/// File size is requested separately via [PresentationFileSize].
/// Capture wall clock is requested separately via
/// [PresentationMetadataRepository.requestCaptureWallClock] (ADR-038).
class PresentationMetadata {
  const PresentationMetadata({
    required this.assetIdentifier,
    required this.mediaKind,
    this.createdAt,
  });

  final String assetIdentifier;
  final PresentationMediaKind mediaKind;

  /// PhotoKit `creationDate`; null when the system value is nil (no epoch).
  /// Used for Overlay relative date (honest Instant vs device now).
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
