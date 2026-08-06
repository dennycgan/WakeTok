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
  iCloudOnly,
  failed,
}

class FeedPageMedia {
  const FeedPageMedia._({
    required this.kind,
    this.display,
    this.videoAssetId,
  });

  factory FeedPageMedia.still(DisplayAsset display) => FeedPageMedia._(
        kind: FeedPageMediaKind.still,
        display: display,
      );

  factory FeedPageMedia.video(String assetIdentifier) => FeedPageMedia._(
        kind: FeedPageMediaKind.video,
        videoAssetId: assetIdentifier,
      );

  factory FeedPageMedia.pendingVideo(String assetIdentifier) => FeedPageMedia._(
        kind: FeedPageMediaKind.pendingVideo,
        videoAssetId: assetIdentifier,
      );

  factory FeedPageMedia.iCloudOnly() =>
      const FeedPageMedia._(kind: FeedPageMediaKind.iCloudOnly);

  factory FeedPageMedia.failed() =>
      const FeedPageMedia._(kind: FeedPageMediaKind.failed);

  final FeedPageMediaKind kind;
  final DisplayAsset? display;
  final String? videoAssetId;
}

/// Cap 7.5 hard routing: Videos → playable only; Photos → display;
/// All → display then unsupportedMedia → video.
///
/// [isCurrent]: only the current page may call playable/plan/load (shared
/// AVPlayer). Off-screen known videos return [FeedPageMedia.pendingVideo].
Future<FeedPageMedia?> loadFeedPageMedia({
  required FeedMediaRequestGate gate,
  required int generation,
  required AssetSourceKind sourceKind,
  required String assetIdentifier,
  required int feedIndex,
  required bool isCurrent,
  required MediaDisplayRepository displayRepository,
  required PlaybackRepository playbackRepository,
}) async {
  if (sourceKind == AssetSourceKind.mediaTypeVideos) {
    return _loadVideo(
      gate: gate,
      generation: generation,
      assetIdentifier: assetIdentifier,
      feedIndex: feedIndex,
      isCurrent: isCurrent,
      displayRepository: displayRepository,
      playbackRepository: playbackRepository,
    );
  }

  try {
    final display =
        await displayRepository.requestDisplayAsset(assetIdentifier);
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return FeedPageMedia.still(display);
  } on PlatformException catch (e) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    if (e.code == 'iCloudDownloadRequired') {
      return FeedPageMedia.iCloudOnly();
    }
    if (sourceKind == AssetSourceKind.entireLibrary &&
        e.code == 'unsupportedMedia') {
      return _loadVideo(
        gate: gate,
        generation: generation,
        assetIdentifier: assetIdentifier,
        feedIndex: feedIndex,
        isCurrent: isCurrent,
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

Future<FeedPageMedia?> _loadVideo({
  required FeedMediaRequestGate gate,
  required int generation,
  required String assetIdentifier,
  required int feedIndex,
  required bool isCurrent,
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
    return FeedPageMedia.video(assetIdentifier);
  } on PlatformException catch (e) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    if (e.code == 'iCloudDownloadRequired') {
      return FeedPageMedia.iCloudOnly();
    }
    return FeedPageMedia.failed();
  } catch (_) {
    if (!gate.isCurrent(generation)) {
      return null;
    }
    return FeedPageMedia.failed();
  }
}
