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

  @override
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier) async {
    final code = displayErrorCode;
    if (code != null) {
      throw PlatformException(code: code, message: 'fake');
    }
    return display ??
        DisplayAsset(
          assetIdentifier: assetIdentifier,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/fake_$assetIdentifier.jpg',
        );
  }

  @override
  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier) async {
    return video ??
        PlayableVideo(
          assetIdentifier: assetIdentifier,
          durationSeconds: 1.0,
        );
  }
}
