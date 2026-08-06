import 'dart:async';

import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';

class FakePlaybackRepository implements PlaybackRepository {
  FakePlaybackRepository();

  final List<String> calls = <String>[];
  final StreamController<PlaybackRestoreRequest> restoreController =
      StreamController<PlaybackRestoreRequest>.broadcast();

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
    calls.add('load:${item.assetIdentifier}');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> seek(double positionSeconds) async {
    calls.add('seek');
  }

  @override
  Future<void> setRate(double rate) async {
    calls.add('setRate');
  }

  @override
  Future<void> setMute(bool muted) async {
    calls.add('setMute');
  }

  @override
  Future<void> setPlaybackPlan(PlaybackPlan plan) async {
    calls.add('setPlaybackPlan:${plan.planId}');
  }

  @override
  Future<void> syncPlanPosition({
    required String assetIdentifier,
    required int feedIndex,
  }) async {
    calls.add('sync:$assetIdentifier:$feedIndex');
  }

  @override
  Future<void> notifyDisplaySurfaceReady(String assetIdentifier) async {
    calls.add('notifyReady:$assetIdentifier');
  }

  @override
  Future<void> updateNowPlayingMetadata() async {
    calls.add('nowPlaying');
  }
}
