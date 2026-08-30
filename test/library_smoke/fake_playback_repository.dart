import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';

class FakePlaybackRepository implements PlaybackRepository {
  FakePlaybackRepository();

  final List<String> calls = <String>[];
  final List<PlaybackIntent> intentCalls = <PlaybackIntent>[];

  /// Per-id delayed completion for [load] (Cap 16.3 video Layer 2).
  final Map<String, Completer<void>> loadGates = <String, Completer<void>>{};

  /// Forced [PlatformException.code] per asset id for [load].
  final Map<String, String> loadErrorById = <String, String>{};

  /// Shared host timeline with [FakeLivePhotoRepository.lifecycleLog].
  List<String>? lifecycleLog;

  final StreamController<PlaybackRestoreRequest> restoreController =
      StreamController<PlaybackRestoreRequest>.broadcast();

  final StreamController<PlaybackSurfaceAttachedEvent>
  surfaceAttachedController =
      StreamController<PlaybackSurfaceAttachedEvent>.broadcast();

  final StreamController<PlaybackSurfaceReadyForDisplayEvent>
  surfaceReadyForDisplayController =
      StreamController<PlaybackSurfaceReadyForDisplayEvent>.broadcast();

  int playbackPoolEpoch = 0;

  /// When non-null, [requestScrubPreviewFrame] returns these bytes (Cap 18.5 tests).
  Uint8List? scrubPreviewBytes;

  /// When true, [seek] throws (Cap 18.5 scrub resilience tests).
  bool seekShouldThrow = false;

  bool transitionAudioSuppressed = false;

  final StreamController<PlaybackRuntimeEvent> _runtimeController =
      StreamController<PlaybackRuntimeEvent>.broadcast();

  /// For widget tests: emit runtime observe ticks.
  void emitRuntimeEvent(PlaybackRuntimeEvent event) {
    _runtimeController.add(event);
  }

  @override
  Stream<PlaybackRuntimeEvent> get runtimeEvents => _runtimeController.stream;

  @override
  Stream<PlaybackRestoreRequest> get restoreRequests =>
      restoreController.stream;

  @override
  Stream<PlaybackSurfaceAttachedEvent> get surfaceAttachedEvents =>
      surfaceAttachedController.stream;

  @override
  Stream<PlaybackSurfaceReadyForDisplayEvent> get surfaceReadyForDisplayEvents =>
      surfaceReadyForDisplayController.stream;

  void emitSurfaceAttached(PlaybackSurfaceAttachedEvent event) {
    surfaceAttachedController.add(event);
  }

  void emitSurfaceReadyForDisplay(PlaybackSurfaceReadyForDisplayEvent event) {
    surfaceReadyForDisplayController.add(event);
  }

  void dispose() {
    restoreController.close();
    surfaceAttachedController.close();
    surfaceReadyForDisplayController.close();
    _runtimeController.close();
  }

  void _record(String entry) {
    calls.add(entry);
    lifecycleLog?.add(entry);
  }

  @override
  Future<void> load(PlaybackItem item) async {
    _record('load:${item.assetIdentifier}');
    final code = loadErrorById[item.assetIdentifier];
    if (code != null) {
      throw PlatformException(code: code, message: 'fake');
    }
    final gate = loadGates[item.assetIdentifier];
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<void> play() async {
    _record('play');
  }

  @override
  Future<void> playFromCurrentPosition() async {
    _record('playFromCurrentPosition');
  }

  @override
  Future<void> pause() async {
    _record('pause');
  }

  @override
  Future<void> seek(double positionSeconds) async {
    _record('seek:$positionSeconds');
    if (seekShouldThrow) {
      throw PlatformException(code: 'seekFailed', message: 'fake seek failure');
    }
  }

  @override
  Future<Uint8List?> requestScrubPreviewFrame(double positionSeconds) async {
    _record('scrubPreview:$positionSeconds');
    return scrubPreviewBytes;
  }

  @override
  Future<void> setRate(double rate) async {
    _record('setRate');
  }

  @override
  Future<void> setMute(bool muted) async {
    _record('setMute:$muted');
  }

  @override
  Future<void> setPlaybackPlan(PlaybackPlan plan) async {
    _record('setPlaybackPlan:${plan.planId}');
  }

  @override
  Future<void> syncPlanPosition({
    required String assetIdentifier,
    required int feedIndex,
  }) async {
    _record('sync:$assetIdentifier:$feedIndex');
  }

  @override
  Future<void> notifyDisplaySurfaceReady(String assetIdentifier) async {
    _record('notifyReady:$assetIdentifier');
  }

  @override
  Future<void> updateNowPlayingMetadata() async {
    _record('nowPlaying');
  }

  @override
  Future<void> clearPlaybackPool() async {
    _record('clearPlaybackPool');
    final error = PlatformException(
      code: 'operationCancelled',
      message: 'Playback load cancelled',
    );
    for (final gate in loadGates.values) {
      if (!gate.isCompleted) {
        gate.completeError(error);
      }
    }
  }

  @override
  Future<void> cancelInFlightPrepare(String assetIdentifier) async {
    _record('cancelInFlightPrepare:$assetIdentifier');
  }

  @override
  Future<void> setTransitionAudioSuppressed(bool suppressed) async {
    transitionAudioSuppressed = suppressed;
    _record('transitionAudioSuppressed:$suppressed');
  }

  @override
  Future<int> getPlaybackPoolEpoch() async => playbackPoolEpoch;

  @override
  Future<void> setPlaybackIntent(PlaybackIntent intent) async {
    intentCalls.add(intent);
    _record(
      'setPlaybackIntent:${intent.assetIdentifier}:'
      'w=${intent.wantsPlay}:nav=${intent.startsNewNavigationActivation}:'
      'clear=${intent.clearsPendingNavigationActivation}',
    );
  }
}
