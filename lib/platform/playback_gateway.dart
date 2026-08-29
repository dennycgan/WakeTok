import 'dart:async';
import 'dart:typed_data';

import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;

PlaybackMediaKind playbackMediaKindFromPigeon(pigeon.MediaKind kind) {
  switch (kind) {
    case pigeon.MediaKind.image:
      return PlaybackMediaKind.image;
    case pigeon.MediaKind.video:
      return PlaybackMediaKind.video;
    case pigeon.MediaKind.livePhoto:
      return PlaybackMediaKind.livePhoto;
    case pigeon.MediaKind.unknown:
      return PlaybackMediaKind.unknown;
  }
}

pigeon.MediaKind mediaKindToPigeon(PlaybackMediaKind kind) {
  switch (kind) {
    case PlaybackMediaKind.image:
      return pigeon.MediaKind.image;
    case PlaybackMediaKind.video:
      return pigeon.MediaKind.video;
    case PlaybackMediaKind.livePhoto:
      return pigeon.MediaKind.livePhoto;
    case PlaybackMediaKind.unknown:
      return pigeon.MediaKind.unknown;
  }
}

PlaybackRuntimeState playbackRuntimeStateFromPigeon(pigeon.PlaybackState state) {
  switch (state) {
    case pigeon.PlaybackState.idle:
      return PlaybackRuntimeState.idle;
    case pigeon.PlaybackState.loading:
      return PlaybackRuntimeState.loading;
    case pigeon.PlaybackState.playing:
      return PlaybackRuntimeState.playing;
    case pigeon.PlaybackState.paused:
      return PlaybackRuntimeState.paused;
    case pigeon.PlaybackState.waitingForMedia:
      return PlaybackRuntimeState.waitingForMedia;
    case pigeon.PlaybackState.failed:
      return PlaybackRuntimeState.failed;
    case pigeon.PlaybackState.completed:
      return PlaybackRuntimeState.completed;
  }
}

/// Pigeon [PlaybackApi] + [PlaybackFlutterApi] adapter (ADR-006 / Cap 7.3).
class PlaybackGateway
    implements PlaybackRepository, pigeon.PlaybackFlutterApi {
  PlaybackGateway({pigeon.PlaybackApi? api})
      : _api = api ?? pigeon.PlaybackApi() {
    pigeon.PlaybackFlutterApi.setUp(this);
  }

  final pigeon.PlaybackApi _api;
  final StreamController<PlaybackRuntimeEvent> _runtimeController =
      StreamController<PlaybackRuntimeEvent>.broadcast();
  final StreamController<PlaybackRestoreRequest> _restoreController =
      StreamController<PlaybackRestoreRequest>.broadcast();
  final StreamController<PlaybackSurfaceAttachedEvent>
  _surfaceAttachedController =
      StreamController<PlaybackSurfaceAttachedEvent>.broadcast();
  final StreamController<PlaybackSurfaceReadyForDisplayEvent>
  _surfaceReadyForDisplayController =
      StreamController<PlaybackSurfaceReadyForDisplayEvent>.broadcast();

  @override
  Stream<PlaybackRuntimeEvent> get runtimeEvents => _runtimeController.stream;

  @override
  Stream<PlaybackRestoreRequest> get restoreRequests =>
      _restoreController.stream;

  @override
  Stream<PlaybackSurfaceAttachedEvent> get surfaceAttachedEvents =>
      _surfaceAttachedController.stream;

  @override
  Stream<PlaybackSurfaceReadyForDisplayEvent> get surfaceReadyForDisplayEvents =>
      _surfaceReadyForDisplayController.stream;

  void dispose() {
    pigeon.PlaybackFlutterApi.setUp(null);
    _runtimeController.close();
    _restoreController.close();
    _surfaceAttachedController.close();
    _surfaceReadyForDisplayController.close();
  }

  @override
  Future<void> load(PlaybackItem item) async {
    await _api.load(
      pigeon.PlaybackItemDto(
        assetIdentifier: item.assetIdentifier,
        feedIndex: item.feedIndex,
        mediaKind: mediaKindToPigeon(item.mediaKind),
      ),
    );
  }

  @override
  Future<void> play() => _api.play();

  @override
  Future<void> pause() => _api.pause();

  @override
  Future<void> seek(double positionSeconds) => _api.seek(positionSeconds);

  @override
  Future<Uint8List?> requestScrubPreviewFrame(double positionSeconds) =>
      _api.requestScrubPreviewFrame(positionSeconds);

  @override
  Future<void> setRate(double rate) => _api.setRate(rate);

  @override
  Future<void> setMute(bool muted) => _api.setMute(muted);

  @override
  Future<void> setPlaybackPlan(PlaybackPlan plan) {
    return _api.setPlaybackPlan(
      pigeon.PlaybackPlanDto(
        planId: plan.planId,
        orderedItems: plan.orderedItems
            .map(
              (item) => pigeon.PlaybackItemDto(
                assetIdentifier: item.assetIdentifier,
                feedIndex: item.feedIndex,
                mediaKind: mediaKindToPigeon(item.mediaKind),
              ),
            )
            .toList(growable: false),
        currentIndex: plan.currentIndex,
      ),
    );
  }

  @override
  Future<void> syncPlanPosition({
    required String assetIdentifier,
    required int feedIndex,
  }) async {
    await _api.syncPlanPosition(assetIdentifier, feedIndex);
  }

  @override
  Future<void> notifyDisplaySurfaceReady(String assetIdentifier) async {
    await _api.notifyDisplaySurfaceReady(assetIdentifier);
  }

  @override
  Future<void> updateNowPlayingMetadata() => _api.updateNowPlayingMetadata();

  @override
  Future<void> clearPlaybackPool() => _api.clearPlaybackPool();

  @override
  Future<void> cancelInFlightPrepare(String assetIdentifier) {
    return _api.cancelInFlightPrepare(assetIdentifier);
  }

  @override
  Future<void> setTransitionAudioSuppressed(bool suppressed) {
    return _api.setTransitionAudioSuppressed(suppressed);
  }

  @override
  Future<int> getPlaybackPoolEpoch() => _api.getPlaybackPoolEpoch();

  @override
  Future<void> setPlaybackIntent(PlaybackIntent intent) {
    return _api.setPlaybackIntent(
      pigeon.PlaybackIntentDto(
        assetIdentifier: intent.assetIdentifier,
        wantsPlay: intent.wantsPlay,
        startsNewNavigationActivation: intent.startsNewNavigationActivation,
        clearsPendingNavigationActivation:
            intent.clearsPendingNavigationActivation,
      ),
    );
  }

  @override
  void onPlaybackSurfaceAttached(pigeon.PlaybackSurfaceAttachedDto event) {
    if (_surfaceAttachedController.isClosed) {
      return;
    }
    _surfaceAttachedController.add(
      PlaybackSurfaceAttachedEvent(
        assetIdentifier: event.assetIdentifier,
        feedIndex: event.feedIndex,
        clearEpoch: event.clearEpoch,
      ),
    );
  }

  @override
  void onPlaybackSurfaceReadyForDisplay(pigeon.PlaybackSurfaceAttachedDto event) {
    if (_surfaceReadyForDisplayController.isClosed) {
      return;
    }
    _surfaceReadyForDisplayController.add(
      PlaybackSurfaceReadyForDisplayEvent(
        assetIdentifier: event.assetIdentifier,
        feedIndex: event.feedIndex,
        clearEpoch: event.clearEpoch,
      ),
    );
  }

  @override
  void onPlaybackRuntimeEvent(pigeon.PlaybackRuntimeEventDto event) {
    if (_runtimeController.isClosed) {
      return;
    }
    _runtimeController.add(
      PlaybackRuntimeEvent(
        planId: event.planId,
        currentItemIdentifier: event.currentItemIdentifier,
        currentIndex: event.currentIndex,
        playbackPositionSeconds: event.playbackPositionSeconds,
        playbackState: playbackRuntimeStateFromPigeon(event.playbackState),
        durationSeconds: event.durationSeconds,
      ),
    );
  }

  @override
  void onPlaybackRestoreRequired(int feedIndex, String assetIdentifier) {
    if (_restoreController.isClosed) {
      return;
    }
    _restoreController.add(
      PlaybackRestoreRequest(
        feedIndex: feedIndex,
        assetIdentifier: assetIdentifier,
      ),
    );
  }

  @override
  void onPlaybackPlanEnded(int feedIndex, String assetIdentifier) {
    // Cap 7.3: no product UI for plan end.
  }
}
