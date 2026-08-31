import 'dart:typed_data';

import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';

/// App-scoped playback intents (ADR-006). Errors surface as channel failures.
abstract class PlaybackRepository {
  Future<void> load(PlaybackItem item);

  Future<void> play();

  /// Cap 18.5 scrub release — play without Host re-enter seek-to-zero.
  Future<void> playFromCurrentPosition();

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

  /// Cap 16.2 / ADR-029: cancel in-flight Host prepare for [assetIdentifier]
  /// even if that id is still current. No-op if none.
  Future<void> cancelInFlightPrepare(String assetIdentifier);

  /// Cap 15.11: temporary mute during shared-PV handoff (does not change [setMute]).
  Future<void> setTransitionAudioSuppressed(bool suppressed);

  /// Cap 15.11: Host [clearEpoch] snapshot for attach-ack / first-frame matching.
  Future<int> getPlaybackPoolEpoch();

  /// Cap 15.11: emitted after active player attaches to Platform View.
  Stream<PlaybackSurfaceAttachedEvent> get surfaceAttachedEvents;

  /// Cap 15.11b: [AVPlayerLayer.isReadyForDisplay] true — same DTO triple as attach.
  Stream<PlaybackSurfaceReadyForDisplayEvent> get surfaceReadyForDisplayEvents;

  /// Native → Dart runtime observe (may be empty until host emits).
  Stream<PlaybackRuntimeEvent> get runtimeEvents;

  /// Native → Dart feed restore (Cap 7.5; may be empty until host emits).
  Stream<PlaybackRestoreRequest> get restoreRequests;

  /// Cap 18.3 / ADR-040: sync intent mirror before effective play/pause.
  Future<void> setPlaybackIntent(PlaybackIntent intent);

  /// Cap 18.5 / ADR-040 Decision 13: preview JPEG + Host actual time, or null.
  Future<ScrubPreviewFrame?> requestScrubPreviewFrame(double positionSeconds);
}
