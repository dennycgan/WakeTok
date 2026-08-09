import 'dart:async';

import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/presentation/presentation_metadata_repository.dart';

/// Test double for Cap 8.5 Overlay wiring.
class FakePresentationMetadataRepository
    implements PresentationMetadataRepository {
  FakePresentationMetadataRepository({
    this.basicsDelay = Duration.zero,
    this.sizeDelay = Duration.zero,
    this.basicsGate,
    this.sizeGate,
    Map<String, PresentationMetadata>? basicsById,
    Map<String, PresentationFileSize>? sizeById,
  })  : basicsById = basicsById ?? {},
        sizeById = sizeById ?? {};

  Duration basicsDelay;
  Duration sizeDelay;
  final Map<String, PresentationMetadata> basicsById;
  final Map<String, PresentationFileSize> sizeById;

  /// Optional hang gate (never complete to prove display is not blocked).
  Completer<void>? basicsGate;
  Completer<void>? sizeGate;

  int basicsCalls = 0;
  int sizeCalls = 0;

  @override
  Future<PresentationMetadata> requestPresentationMetadata(
    String assetIdentifier,
  ) async {
    basicsCalls += 1;
    final gate = basicsGate;
    if (gate != null) {
      await gate.future;
    }
    if (basicsDelay > Duration.zero) {
      await Future<void>.delayed(basicsDelay);
    }
    return basicsById[assetIdentifier] ??
        PresentationMetadata(
          assetIdentifier: assetIdentifier,
          mediaKind: PresentationMediaKind.image,
          createdAt: DateTime.utc(2024, 6, 1, 12),
        );
  }

  @override
  Future<PresentationFileSize> requestPresentationFileSize(
    String assetIdentifier,
  ) async {
    sizeCalls += 1;
    final gate = sizeGate;
    if (gate != null) {
      await gate.future;
    }
    if (sizeDelay > Duration.zero) {
      await Future<void>.delayed(sizeDelay);
    }
    return sizeById[assetIdentifier] ??
        PresentationFileSize(
          assetIdentifier: assetIdentifier,
          fileSizeBytes: 2048,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        );
  }
}
