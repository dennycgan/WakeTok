import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';

/// Session-scoped presentation file-size entry (Cap 26.4 shared Overlay / "…"
/// half-sheet source of truth).
@immutable
class PresentationSizeEntry {
  const PresentationSizeEntry({
    this.fileSizeBytes,
    this.fileSizeSemantics,
    this.resolved = false,
  });

  final int? fileSizeBytes;
  final FileSizeSemantics? fileSizeSemantics;

  /// True after at least one Host size response was applied for this asset.
  final bool resolved;
}

/// Same keepExisting rule as [PresentationOverlaySnapshot.mergeSize] / S-6:
/// a later nil must not clobber existing non-null bytes.
PresentationSizeEntry mergePresentationSizeEntry(
  PresentationSizeEntry? existing,
  PresentationFileSize size,
) {
  final prevBytes = existing?.fileSizeBytes;
  final keepExisting = prevBytes != null && size.fileSizeBytes == null;
  return PresentationSizeEntry(
    fileSizeBytes: keepExisting ? prevBytes : size.fileSizeBytes,
    fileSizeSemantics: keepExisting
        ? existing?.fileSizeSemantics
        : size.fileSizeSemantics,
    resolved: true,
  );
}

/// Per-asset presentation size cache for Browse (Overlay + Cap 24 "…" sheet).
final presentationSizeCacheProvider = NotifierProvider<
    PresentationSizeCacheNotifier, Map<String, PresentationSizeEntry>>(
  PresentationSizeCacheNotifier.new,
);

class PresentationSizeCacheNotifier
    extends Notifier<Map<String, PresentationSizeEntry>> {
  @override
  Map<String, PresentationSizeEntry> build() =>
      const <String, PresentationSizeEntry>{};

  /// Apply a Host size result. Sole write path for shared size (keepExisting).
  void apply(String assetId, PresentationFileSize size) {
    if (assetId.isEmpty) {
      return;
    }
    final next = Map<String, PresentationSizeEntry>.of(state);
    next[assetId] = mergePresentationSizeEntry(state[assetId], size);
    state = next;
  }
}
