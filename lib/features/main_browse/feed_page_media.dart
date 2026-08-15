import 'package:flutter/services.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';

enum FeedPageMediaKind {
  still,
  video,

  /// Known video, but not current — do not touch the shared AVPlayer.
  pendingVideo,
  failed,
}

enum FeedDisplayLayer { preview, full }

class FeedPageMedia {
  const FeedPageMedia._({
    required this.kind,
    this.display,
    this.videoAssetId,
    this.displayLayer,
  });

  factory FeedPageMedia.still(
    DisplayAsset display, {
    required FeedDisplayLayer layer,
  }) => FeedPageMedia._(
    kind: FeedPageMediaKind.still,
    display: display,
    displayLayer: layer,
  );

  factory FeedPageMedia.video(String assetIdentifier, {DisplayAsset? poster}) =>
      FeedPageMedia._(
        kind: FeedPageMediaKind.video,
        videoAssetId: assetIdentifier,
        display: poster,
        displayLayer: poster == null ? null : FeedDisplayLayer.preview,
      );

  factory FeedPageMedia.pendingVideo(String assetIdentifier) => FeedPageMedia._(
    kind: FeedPageMediaKind.pendingVideo,
    videoAssetId: assetIdentifier,
  );

  factory FeedPageMedia.failed() =>
      const FeedPageMedia._(kind: FeedPageMediaKind.failed);

  final FeedPageMediaKind kind;
  final DisplayAsset? display;
  final String? videoAssetId;
  final FeedDisplayLayer? displayLayer;
}

/// Layer 1: local preview JPEG (still / Live key / video poster).
///
/// Misses (`iCloudDownloadRequired`, cancel, other errors) return null —
/// not a user-visible failure.
Future<FeedPageMedia?> loadFeedPageLayer1({
  required FeedMediaRequestGate gate,
  required int generation,
  required String assetIdentifier,
  required MediaDisplayRepository displayRepository,
}) async {
  try {
    final preview = await displayRepository.requestPreview(assetIdentifier);
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return FeedPageMedia.still(preview, layer: FeedDisplayLayer.preview);
  } on PlatformException catch (_) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return null;
  } catch (_) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return null;
  }
}

/// Layer 2: current-item full still or playable video. Off-current videos
/// return [FeedPageMedia.pendingVideo] without touching the player.
Future<FeedPageMedia?> loadFeedPageLayer2({
  required FeedMediaRequestGate gate,
  required int generation,
  required AssetSourceKind sourceKind,
  required String assetIdentifier,
  required int feedIndex,
  required bool isCurrent,
  required FeedPageMedia? layer1,
  required MediaDisplayRepository displayRepository,
  required PlaybackRepository playbackRepository,
}) async {
  final previewKind = layer1?.display?.mediaKind;
  final treatAsVideo =
      sourceKind == AssetSourceKind.mediaTypeVideos ||
      previewKind == PlaybackMediaKind.video;

  if (treatAsVideo) {
    return _loadVideo(
      gate: gate,
      generation: generation,
      assetIdentifier: assetIdentifier,
      feedIndex: feedIndex,
      isCurrent: isCurrent,
      poster: layer1?.display,
      displayRepository: displayRepository,
      playbackRepository: playbackRepository,
    );
  }

  if (sourceKind == AssetSourceKind.mediaTypePhotos ||
      sourceKind == AssetSourceKind.entireLibrary) {
    try {
      final display = await displayRepository.requestDisplayAsset(
        assetIdentifier,
      );
      if (!gate.isCurrent(generation)) {
        return null;
      }
      return FeedPageMedia.still(display, layer: FeedDisplayLayer.full);
    } on PlatformException catch (e) {
      if (!gate.isCurrent(generation)) {
        return null;
      }
      if (e.code == 'operationCancelled') {
        return null;
      }
      if (sourceKind == AssetSourceKind.entireLibrary &&
          e.code == 'unsupportedMedia') {
        return _loadVideo(
          gate: gate,
          generation: generation,
          assetIdentifier: assetIdentifier,
          feedIndex: feedIndex,
          isCurrent: isCurrent,
          poster: layer1?.display,
          displayRepository: displayRepository,
          playbackRepository: playbackRepository,
        );
      }
      return FeedPageMedia.failed();
    } catch (_) {
      if (!gate.isCurrent(generation)) {
        return null;
      }
      return FeedPageMedia.failed();
    }
  }

  return FeedPageMedia.failed();
}

Future<FeedPageMedia?> _loadVideo({
  required FeedMediaRequestGate gate,
  required int generation,
  required String assetIdentifier,
  required int feedIndex,
  required bool isCurrent,
  required DisplayAsset? poster,
  required MediaDisplayRepository displayRepository,
  required PlaybackRepository playbackRepository,
}) async {
  if (!isCurrent) {
    return FeedPageMedia.pendingVideo(assetIdentifier);
  }
  try {
    await displayRepository.requestPlayableVideo(assetIdentifier);
    if (!gate.isCurrent(generation)) {
      return null;
    }
    final item = PlaybackItem(
      assetIdentifier: assetIdentifier,
      feedIndex: feedIndex,
      mediaKind: PlaybackMediaKind.video,
    );
    await playbackRepository.setPlaybackPlan(
      PlaybackPlan(
        planId: 'feed-$assetIdentifier-$feedIndex',
        orderedItems: [item],
        currentIndex: 0,
      ),
    );
    if (!gate.isCurrent(generation)) {
      return null;
    }
    await playbackRepository.load(item);
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return FeedPageMedia.video(assetIdentifier, poster: poster);
  } on PlatformException catch (e) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    if (e.code == 'operationCancelled') {
      return null;
    }
    return FeedPageMedia.failed();
  } catch (_) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return FeedPageMedia.failed();
  }
}
