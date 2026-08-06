/// Domain types for Cap 7.3 playback + display presentation.
library;

enum PlaybackMediaKind {
  image,
  video,
  livePhoto,
  unknown,
}

class PlaybackItem {
  const PlaybackItem({
    required this.assetIdentifier,
    required this.feedIndex,
    required this.mediaKind,
  });

  final String assetIdentifier;
  final int feedIndex;
  final PlaybackMediaKind mediaKind;
}

class PlaybackPlan {
  const PlaybackPlan({
    required this.planId,
    required this.orderedItems,
    required this.currentIndex,
  });

  final String planId;
  final List<PlaybackItem> orderedItems;
  final int currentIndex;
}

enum PlaybackRuntimeState {
  idle,
  loading,
  playing,
  paused,
  waitingForMedia,
  failed,
  completed,
}

class PlaybackRuntimeEvent {
  const PlaybackRuntimeEvent({
    required this.planId,
    required this.currentItemIdentifier,
    required this.currentIndex,
    required this.playbackPositionSeconds,
    required this.playbackState,
  });

  final String planId;
  final String currentItemIdentifier;
  final int currentIndex;
  final double playbackPositionSeconds;
  final PlaybackRuntimeState playbackState;
}

/// Native asks Dart to sync the feed to [feedIndex] (Cap 7.5).
class PlaybackRestoreRequest {
  const PlaybackRestoreRequest({
    required this.feedIndex,
    required this.assetIdentifier,
  });

  final int feedIndex;
  final String assetIdentifier;
}

/// Still (or Live Photo key frame) ready for Flutter [Image.file].
class DisplayAsset {
  const DisplayAsset({
    required this.assetIdentifier,
    required this.mediaKind,
    required this.localFilePath,
    this.pixelWidth,
    this.pixelHeight,
  });

  final String assetIdentifier;
  final PlaybackMediaKind mediaKind;
  final String localFilePath;
  final int? pixelWidth;
  final int? pixelHeight;
}

class PlayableVideo {
  const PlayableVideo({
    required this.assetIdentifier,
    this.durationSeconds,
  });

  final String assetIdentifier;
  final double? durationSeconds;
}
