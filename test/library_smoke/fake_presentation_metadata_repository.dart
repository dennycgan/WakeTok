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
    this.hangOnSizeCall,
    Map<String, PresentationMetadata>? basicsById,
    Map<String, PresentationFileSize>? sizeById,
    Map<String, List<PresentationFileSize>>? sizeSequenceById,
  }) : basicsById = basicsById ?? {},
       sizeById = sizeById ?? {},
       sizeSequenceById = sizeSequenceById ?? {};

  Duration basicsDelay;
  Duration sizeDelay;
  final Map<String, PresentationMetadata> basicsById;
  final Map<String, PresentationFileSize> sizeById;
  final Map<String, List<PresentationFileSize>> sizeSequenceById;

  /// Optional hang gate (never complete to prove display is not blocked).
  Completer<void>? basicsGate;
  Completer<void>? sizeGate;

  /// When set, [sizeGate] applies only to this 1-based [sizeCalls] index.
  int? hangOnSizeCall;

  int basicsCalls = 0;
  int sizeCalls = 0;
  final Map<String, int> sizeCallsById = <String, int>{};

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
    sizeCallsById[assetIdentifier] = (sizeCallsById[assetIdentifier] ?? 0) + 1;
    final hangIndex = hangOnSizeCall;
    if (hangIndex != null) {
      if (sizeCalls == hangIndex) {
        final gate = sizeGate;
        if (gate != null) {
          await gate.future;
        }
      }
    } else {
      final gate = sizeGate;
      if (gate != null) {
        await gate.future;
      }
    }
    if (sizeDelay > Duration.zero) {
      await Future<void>.delayed(sizeDelay);
    }
    final sequence = sizeSequenceById[assetIdentifier];
    if (sequence != null && sequence.isNotEmpty) {
      final i = sizeCallsById[assetIdentifier]! - 1;
      return sequence[i < sequence.length ? i : sequence.length - 1];
    }
    return sizeById[assetIdentifier] ??
        PresentationFileSize(
          assetIdentifier: assetIdentifier,
          fileSizeBytes: 2048,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        );
  }
}
