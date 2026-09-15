import 'dart:async';

import 'package:flutter/services.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';

/// Test double for Cap 9.4 Feed Live orchestration.
class FakeLivePhotoRepository implements LivePhotoRepository {
  FakeLivePhotoRepository({this.throwOnRequestCode, this.autoReady = false});

  /// When set, [requestLivePhoto] throws [PlatformException] with this code.
  final String? throwOnRequestCode;

  /// When true, emits [readyEvents] after each successful request.
  /// Mutable so Cap 26 Path S tests can settle auto play then require manual ready.
  bool autoReady;

  /// When set with [cancelHold], [cancel] for this asset id awaits the hold.
  String? cancelHoldAssetId;

  /// Paired with [cancelHoldAssetId] (L-F8).
  Completer<void>? cancelHold;

  /// When set with [requestHold], [requestLivePhoto] for this asset id awaits
  /// the hold after recording the call (U-26.2-4 / W-26.2-e serial).
  String? requestHoldAssetId;

  /// Paired with [requestHoldAssetId].
  Completer<void>? requestHold;

  final List<String> calls = <String>[];

  /// Shared host timeline with [FakePlaybackRepository.lifecycleLog].
  List<String>? lifecycleLog;

  void _record(String entry) {
    calls.add(entry);
    lifecycleLog?.add(entry);
  }

  final StreamController<LivePhotoReadyEvent> readyController =
      StreamController<LivePhotoReadyEvent>.broadcast();
  final StreamController<LivePhotoFailedEvent> failedController =
      StreamController<LivePhotoFailedEvent>.broadcast();
  final StreamController<LivePhotoPlaybackEndedEvent> endedController =
      StreamController<LivePhotoPlaybackEndedEvent>.broadcast();

  @override
  Stream<LivePhotoReadyEvent> get readyEvents => readyController.stream;

  @override
  Stream<LivePhotoFailedEvent> get failedEvents => failedController.stream;

  @override
  Stream<LivePhotoPlaybackEndedEvent> get playbackEndedEvents =>
      endedController.stream;

  void dispose() {
    readyController.close();
    failedController.close();
    endedController.close();
  }

  @override
  Future<void> requestLivePhoto(String assetIdentifier) async {
    _record('requestLivePhoto:$assetIdentifier');
    final code = throwOnRequestCode;
    if (code != null) {
      throw PlatformException(code: code, message: 'fake');
    }
    final hold = requestHold;
    final holdId = requestHoldAssetId;
    if (hold != null &&
        (holdId == null || holdId == assetIdentifier)) {
      await hold.future;
    }
    if (autoReady) {
      readyController.add(
        LivePhotoReadyEvent(assetIdentifier: assetIdentifier),
      );
    }
  }

  @override
  Future<void> cancel(String assetIdentifier) async {
    _record('cancel:$assetIdentifier');
    final hold = cancelHold;
    final holdId = cancelHoldAssetId;
    // All matching cancels await the same Future (multi-await OK) so a
    // re-created page State cannot bypass a leave hold that already started.
    if (hold != null && holdId != null && assetIdentifier == holdId) {
      await hold.future;
    }
  }

  @override
  Future<void> startPlayback() async {
    _record('startPlayback');
  }

  @override
  Future<void> stopPlayback() async {
    _record('stopPlayback');
  }

  @override
  Future<void> setMute(bool muted) async {
    _record('setMute:$muted');
  }

  @override
  Future<void> notifyLiveSurfaceReady(String assetIdentifier) async {
    _record('notifyLiveSurfaceReady:$assetIdentifier');
  }
}
