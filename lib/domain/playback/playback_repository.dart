import 'package:waketok/domain/playback/playback_models.dart';

/// App-scoped playback intents (ADR-006). Errors surface as channel failures.
abstract class PlaybackRepository {
  Future<void> load(PlaybackItem item);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(double positionSeconds);

  Future<void> setRate(double rate);

  Future<void> setMute(bool muted);

  Future<void> setPlaybackPlan(PlaybackPlan plan);

  Future<void> syncPlanPosition({
    required String assetIdentifier,
    required int feedIndex,
  });

  Future<void> notifyDisplaySurfaceReady(String assetIdentifier);

  /// Stub until Production Background Audio.
  Future<void> updateNowPlayingMetadata();

  /// Cap 9 / ADR-019: release active+warming AVPlayers before Live motion.
  Future<void> clearPlaybackPool();

  /// Native → Dart runtime observe (may be empty until host emits).
  Stream<PlaybackRuntimeEvent> get runtimeEvents;

  /// Native → Dart feed restore (Cap 7.5; may be empty until host emits).
  Stream<PlaybackRestoreRequest> get restoreRequests;
}
