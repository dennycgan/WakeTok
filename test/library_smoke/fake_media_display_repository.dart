import 'dart:async';

import 'package:flutter/services.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';

class FakeMediaDisplayRepository implements MediaDisplayRepository {
  FakeMediaDisplayRepository({
    this.display,
    this.video,
    this.displayErrorCode,
  });

  DisplayAsset? display;
  PlayableVideo? video;
  String? displayErrorCode;

  /// Per-id display overrides (takes precedence over [display]).
  final Map<String, DisplayAsset> displaysById = <String, DisplayAsset>{};

  /// Per-id delayed completion for display requests (W-F7).
  final Map<String, Completer<void>> displayGates = <String, Completer<void>>{};

  /// Forced [PlatformException.code] per asset id for display.
  final Map<String, String> displayErrorById = <String, String>{};

  final List<String> displayCalls = <String>[];
  final List<String> playableCalls = <String>[];

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
  Future<void> cancelDisplayAsset(String assetIdentifier) async {}

  @override
  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier) async {
    playableCalls.add(assetIdentifier);
    return video ??
        PlayableVideo(
          assetIdentifier: assetIdentifier,
          durationSeconds: 1.0,
        );
  }

  @override
  Future<void> cancelPlayableVideo(String assetIdentifier) async {}

  @override
  Future<DisplayAsset> requestPreview(String assetIdentifier) async {
    return DisplayAsset(
      assetIdentifier: assetIdentifier,
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/fake_preview_$assetIdentifier.jpg',
    );
  }

  @override
  Future<void> cancelPreview(String assetIdentifier) async {}

  @override
  Future<void> releasePreview(String assetIdentifier) async {}
}
