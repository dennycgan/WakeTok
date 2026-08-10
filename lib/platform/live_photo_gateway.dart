import 'dart:async';

import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;

/// Pigeon [LivePhotoApi] + [LivePhotoFlutterApi] adapter (ADR-019 / Cap 9.3).
///
/// Failure split: sync throws from [requestLivePhoto]; async failures only via
/// [failedEvents] ([onLivePhotoFailed]).
class LivePhotoGateway
    implements LivePhotoRepository, pigeon.LivePhotoFlutterApi {
  LivePhotoGateway({pigeon.LivePhotoApi? api})
      : _api = api ?? pigeon.LivePhotoApi() {
    pigeon.LivePhotoFlutterApi.setUp(this);
  }

  final pigeon.LivePhotoApi _api;
  final StreamController<LivePhotoReadyEvent> _readyController =
      StreamController<LivePhotoReadyEvent>.broadcast();
  final StreamController<LivePhotoFailedEvent> _failedController =
      StreamController<LivePhotoFailedEvent>.broadcast();
  final StreamController<LivePhotoPlaybackEndedEvent> _endedController =
      StreamController<LivePhotoPlaybackEndedEvent>.broadcast();

  @override
  Stream<LivePhotoReadyEvent> get readyEvents => _readyController.stream;

  @override
  Stream<LivePhotoFailedEvent> get failedEvents => _failedController.stream;

  @override
  Stream<LivePhotoPlaybackEndedEvent> get playbackEndedEvents =>
      _endedController.stream;

  /// Test-only teardown (mirrors [PlaybackGateway.dispose]). Production
  /// composition root does not call this.
  void dispose() {
    pigeon.LivePhotoFlutterApi.setUp(null);
    _readyController.close();
    _failedController.close();
    _endedController.close();
  }

  @override
  Future<void> requestLivePhoto(String assetIdentifier) {
    return _api.requestLivePhoto(assetIdentifier);
  }

  @override
  Future<void> cancel(String assetIdentifier) {
    return _api.cancel(assetIdentifier);
  }

  @override
  Future<void> startPlayback() => _api.startPlayback();

  @override
  Future<void> stopPlayback() => _api.stopPlayback();

  @override
  Future<void> setMute(bool muted) => _api.setMute(muted);

  @override
  Future<void> notifyLiveSurfaceReady(String assetIdentifier) {
    return _api.notifyLiveSurfaceReady(assetIdentifier);
  }

  @override
  void onLivePhotoReady(String assetIdentifier) {
    if (_readyController.isClosed) {
      return;
    }
    _readyController.add(
      LivePhotoReadyEvent(assetIdentifier: assetIdentifier),
    );
  }

  @override
  void onLivePhotoFailed(String assetIdentifier, pigeon.ErrorCode errorCode) {
    if (_failedController.isClosed) {
      return;
    }
    _failedController.add(
      LivePhotoFailedEvent(
        assetIdentifier: assetIdentifier,
        error: appErrorFromErrorCode(errorCode),
      ),
    );
  }

  @override
  void onLivePhotoPlaybackEnded(String assetIdentifier) {
    if (_endedController.isClosed) {
      return;
    }
    _endedController.add(
      LivePhotoPlaybackEndedEvent(assetIdentifier: assetIdentifier),
    );
  }
}
