import 'dart:async';

import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';

class FakePlaybackRepository implements PlaybackRepository {
  FakePlaybackRepository();

  final List<String> calls = <String>[];

  /// Shared host timeline with [FakeLivePhotoRepository.lifecycleLog].
  List<String>? lifecycleLog;

  final StreamController<PlaybackRestoreRequest> restoreController =
      StreamController<PlaybackRestoreRequest>.broadcast();

  void _record(String entry) {
    calls.add(entry);
    lifecycleLog?.add(entry);
  }

  @override
  Stream<PlaybackRuntimeEvent> get runtimeEvents => const Stream.empty();

  @override
  Stream<PlaybackRestoreRequest> get restoreRequests =>
      restoreController.stream;

  void dispose() {
    restoreController.close();
  }

  @override
  Future<void> load(PlaybackItem item) async {
    _record('load:${item.assetIdentifier}');
  }

  @override
  Future<void> play() async {
    _record('play');
  }

  @override
  Future<void> pause() async {
    _record('pause');
  }

  @override
  Future<void> seek(double positionSeconds) async {
    _record('seek');
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
  }
}
