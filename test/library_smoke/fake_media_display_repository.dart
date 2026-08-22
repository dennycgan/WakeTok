import 'dart:async';

import 'package:flutter/services.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';

class FakeMediaDisplayRepository implements MediaDisplayRepository {
  FakeMediaDisplayRepository({this.display, this.video, this.displayErrorCode});

  DisplayAsset? display;
  PlayableVideo? video;
  String? displayErrorCode;

  /// Per-id display overrides (takes precedence over [display]).
  final Map<String, DisplayAsset> displaysById = <String, DisplayAsset>{};

  /// Per-id preview overrides.
  final Map<String, DisplayAsset> previewsById = <String, DisplayAsset>{};

  /// Per-id delayed completion for display requests (W-F7).
  final Map<String, Completer<void>> displayGates = <String, Completer<void>>{};

  /// Per-id delayed completion for preview requests.
  final Map<String, Completer<void>> previewGates = <String, Completer<void>>{};

  /// When set, [requestPreview] waits on [previewGates] only after this many
  /// calls for that id (1-based). Used by W-15.7d to hold a *second* preheat.
  final Map<String, int> previewGateAfterCall = <String, int>{};

  /// Per-id delayed completion for playable-video requests.
  final Map<String, Completer<void>> playableGates =
      <String, Completer<void>>{};

  /// Forced [PlatformException.code] per asset id for display.
  final Map<String, String> displayErrorById = <String, String>{};

  /// Forced [PlatformException.code] per asset id for preview.
  final Map<String, String> previewErrorById = <String, String>{};

  final List<String> displayCalls = <String>[];
  final List<String> playableCalls = <String>[];
  final List<String> previewCalls = <String>[];
  final List<String> cancelDisplayCalls = <String>[];
  final List<String> cancelPlayableCalls = <String>[];
  final List<String> cancelPreviewCalls = <String>[];
  final List<String> releasePreviewCalls = <String>[];
  final List<String> previewLifecycleLog = <String>[];

  /// When set, [releasePreview] waits before completing.
  Completer<void>? releaseGate;

  @override
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier) async {
    displayCalls.add(assetIdentifier);
    final gate = displayGates[assetIdentifier];
    if (gate != null) {
      await gate.future;
    }
    final perIdError = displayErrorById[assetIdentifier];
    if (perIdError != null) {
      throw PlatformException(code: perIdError, message: 'fake');
    }
    final code = displayErrorCode;
    if (code != null) {
      throw PlatformException(code: code, message: 'fake');
    }
    return displaysById[assetIdentifier] ??
        display ??
        DisplayAsset(
          assetIdentifier: assetIdentifier,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/fake_$assetIdentifier.jpg',
        );
  }

  @override
  Future<void> cancelDisplayAsset(String assetIdentifier) async {
    cancelDisplayCalls.add(assetIdentifier);
  }

  @override
  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier) async {
    playableCalls.add(assetIdentifier);
    final gate = playableGates[assetIdentifier];
    if (gate != null) {
      await gate.future;
    }
    return video ??
        PlayableVideo(assetIdentifier: assetIdentifier, durationSeconds: 1.0);
  }

  @override
  Future<void> cancelPlayableVideo(String assetIdentifier) async {
    cancelPlayableCalls.add(assetIdentifier);
  }

  @override
  Future<DisplayAsset> requestPreview(String assetIdentifier) async {
    previewCalls.add(assetIdentifier);
    previewLifecycleLog.add('preview:$assetIdentifier');
    final gate = previewGates[assetIdentifier];
    final after = previewGateAfterCall[assetIdentifier];
    final callCount = previewCalls.where((id) => id == assetIdentifier).length;
    final shouldWait = gate != null &&
        (after == null || callCount >= after);
    if (shouldWait) {
      await gate.future;
    }
    final perIdError = previewErrorById[assetIdentifier];
    if (perIdError != null) {
      throw PlatformException(code: perIdError, message: 'fake');
    }
    return previewsById[assetIdentifier] ??
        DisplayAsset(
          assetIdentifier: assetIdentifier,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/fake_preview_$assetIdentifier.jpg',
        );
  }

  @override
  Future<void> cancelPreview(String assetIdentifier) async {
    cancelPreviewCalls.add(assetIdentifier);
  }

  @override
  Future<void> releasePreview(String assetIdentifier) async {
    releasePreviewCalls.add(assetIdentifier);
    previewLifecycleLog.add('release:$assetIdentifier');
    final gate = releaseGate;
    if (gate != null) {
      await gate.future;
    }
  }
}
