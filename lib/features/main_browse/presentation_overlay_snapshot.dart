import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/presentation_size_cache.dart';

/// Session-scoped Overlay field snapshot (ADR-015 Decision 3).
class PresentationOverlaySnapshot {
  const PresentationOverlaySnapshot({
    required this.assetIdentifier,
    this.createdAt,
    this.mediaKind,
    this.isAnimated = false,
    this.fileSizeBytes,
    this.fileSizeSemantics,
    this.locationLabel,
  });

  final String assetIdentifier;
  final DateTime? createdAt;
  final PresentationMediaKind? mediaKind;

  /// Cap 26.3 / ADR-053 — Overlay row-3 Animated prefix only.
  final bool isAnimated;
  final int? fileSizeBytes;
  final FileSizeSemantics? fileSizeSemantics;

  /// Resolved place name for Overlay row 4; null/empty collapses the row.
  /// Cap 8 never fills this (Q1=B); field exists so layout can stay Photo-App-A-aligned.
  final String? locationLabel;

  PresentationOverlaySnapshot mergeBasics(PresentationMetadata meta) {
    return PresentationOverlaySnapshot(
      assetIdentifier: meta.assetIdentifier,
      createdAt: meta.createdAt,
      mediaKind: meta.mediaKind,
      isAnimated: meta.isAnimated,
      fileSizeBytes: fileSizeBytes,
      fileSizeSemantics: fileSizeSemantics,
      locationLabel: locationLabel,
    );
  }

  PresentationOverlaySnapshot mergeSize(PresentationFileSize size) {
    // Same metadata generation can complete two size requests out of order
    // (activation nil after Layer-2 refresh). isCurrent cannot drop the nil.
    // keepExisting rule lives in [mergePresentationSizeEntry] (S-6 / Cap 26.4).
    final merged = mergePresentationSizeEntry(
      PresentationSizeEntry(
        fileSizeBytes: fileSizeBytes,
        fileSizeSemantics: fileSizeSemantics,
        resolved: true,
      ),
      size,
    );
    return PresentationOverlaySnapshot(
      assetIdentifier: assetIdentifier,
      createdAt: createdAt,
      mediaKind: mediaKind,
      isAnimated: isAnimated,
      fileSizeBytes: merged.fileSizeBytes,
      fileSizeSemantics: merged.fileSizeSemantics,
      locationLabel: locationLabel,
    );
  }
}
