import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/shared_mute_provider.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/playback_coordinator_provider.dart';

/// Per-page handoff eligibility reported by [MediaFeedPage].
class PvHandoffPageSnapshot {
  const PvHandoffPageSnapshot({
    this.isVideoWithPoster = false,
    this.isCurrentSurfaceReady = false,
    this.posterPath,
  });

  final bool isVideoWithPoster;
  final bool isCurrentSurfaceReady;
  final String? posterPath;
}

class PvTransitionGuardState {
  const PvTransitionGuardState({
    this.targetAssetId,
    this.targetFeedIndex,
    this.coverPosterPath,
    this.displayGeneration,
    this.armPoolEpoch,
  });

  final String? targetAssetId;
  final int? targetFeedIndex;
  final String? coverPosterPath;

  /// Dart-side epoch from [FeedActivationCoordinator.currentDisplayGate] at arm.
  /// Recorded for diagnostics; ready-for-display unwrap does not re-check this
  /// gate (same settle race as former attach-ack — see [_onReadyForDisplay]).
  final int? displayGeneration;

  /// Host pool epoch snapshot at arm ([PlaybackRepository.getPlaybackPoolEpoch]).
  final int? armPoolEpoch;

  bool isCovering(String assetId) =>
      targetAssetId == assetId && coverPosterPath != null;
}

class PvTransitionGuardNotifier extends Notifier<PvTransitionGuardState> {
  final Map<String, PvHandoffPageSnapshot> _pages = <String, PvHandoffPageSnapshot>{};
  StreamSubscription<PlaybackSurfaceReadyForDisplayEvent>? _readySub;
  Timer? _timeoutTimer;
  FeedMediaRequestGate? _armedDisplayGate;

  /// Transition mute outlives covering after [releaseCovering] (settle-on-target).
  bool _transitionAudioHeld = false;
  String? _audioHoldAssetId;
  int? _audioHoldFeedIndex;
  int? _audioHoldEpoch;

  @override
  PvTransitionGuardState build() {
    ref.onDispose(_dispose);
    _readySub?.cancel();
    _readySub = ref
        .read(playbackRepositoryProvider)
        .surfaceReadyForDisplayEvents
        .listen(_onReadyForDisplay);
    return const PvTransitionGuardState();
  }

  void _dispose() {
    _timeoutTimer?.cancel();
    _readySub?.cancel();
  }

  void updatePageSnapshot(String assetId, PvHandoffPageSnapshot snapshot) {
    _pages[assetId] = snapshot;
  }

  void removePageSnapshot(String assetId) {
    _pages.remove(assetId);
  }

  Future<void> tryArmOnScroll({
    required int currentFeedIndex,
    required int targetFeedIndex,
    required String sourceAssetId,
    required String targetAssetId,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
  }) async {
    // Cap 15.11b defensive: never arm a handoff onto the page we already are.
    // Catches stale curIdx→target races after settle even if a caller still
    // passes pre-settle indices.
    final liveIndex = ref.read(mainBrowseFeedIndexProvider);
    if (targetFeedIndex == liveIndex) {
      return;
    }
    if (state.targetAssetId != null) {
      return;
    }
    final source = _pages[sourceAssetId];
    final target = _pages[targetAssetId];
    if (source == null ||
        target == null ||
        !source.isVideoWithPoster ||
        !target.isVideoWithPoster ||
        !source.isCurrentSurfaceReady ||
        target.posterPath == null) {
      return;
    }
    if (!displayGate.isCurrent(displayGeneration)) {
      return;
    }
    final playback = ref.read(playbackRepositoryProvider);
    // Epoch is async; do not re-check displayGeneration here — settle can bump
    // the gate while awaiting. Stale arms are rejected on ready-for-display.
    final poolEpoch = await playback.getPlaybackPoolEpoch();
    if (state.targetAssetId != null) {
      return;
    }
    // Re-check after await: settle may have landed on [targetFeedIndex].
    final liveAfterAwait = ref.read(mainBrowseFeedIndexProvider);
    if (targetFeedIndex == liveAfterAwait) {
      return;
    }
    await playback.setTransitionAudioSuppressed(true);
    _transitionAudioHeld = true;
    _audioHoldAssetId = targetAssetId;
    _audioHoldFeedIndex = targetFeedIndex;
    _audioHoldEpoch = poolEpoch;
    _armedDisplayGate = displayGate;
    state = PvTransitionGuardState(
      targetAssetId: targetAssetId,
      targetFeedIndex: targetFeedIndex,
      coverPosterPath: target.posterPath,
      displayGeneration: displayGeneration,
      armPoolEpoch: poolEpoch,
    );
    _armTimeout();
  }

  /// Near-settled / ScrollEnd helper for **abandoning** an armed target.
  ///
  /// When [feedIndex] **equals** [PvTransitionGuardState.targetFeedIndex], this
  /// is a deliberate no-op: settle-on-target covering release is **only** via
  /// [onFeedIndexChanged] (true feed-index commit). Do not use the epsilon
  /// near-settled heuristic to end defer — that can fire mid-peek.
  void maybeDisarmOnSettled(int feedIndex) {
    if (state.targetAssetId == null) {
      return;
    }
    if (state.targetFeedIndex == feedIndex) {
      return;
    }
    unawaited(disarm(reason: 'scroll-settled', settledIdx: feedIndex));
  }

  /// True feed-index commit (same provider listen as [_activateCurrentItem]).
  void onFeedIndexChanged(int newIndex) {
    if (state.targetAssetId == null && !_transitionAudioHeld) {
      return;
    }
    if (state.targetAssetId != null && state.targetFeedIndex == newIndex) {
      // Cap 15.11b: end defer only — audio stays suppressed until hold clear.
      unawaited(
        releaseCovering(reason: 'settled-on-target', settledIdx: newIndex),
      );
      return;
    }
    if (state.targetAssetId != null && state.targetFeedIndex != newIndex) {
      unawaited(disarm(reason: 'feed-index', newIdx: newIndex));
    }
  }

  /// Visual half of disarm: clears covering/defer so PV may mount.
  /// Does **not** call [PlaybackRepository.setTransitionAudioSuppressed](false).
  Future<void> releaseCovering({
    required String reason,
    int? settledIdx,
  }) async {
    final hadTarget = state.targetAssetId;
    if (hadTarget == null) {
      return;
    }
    final targetIndex = state.targetFeedIndex;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    // Preserve audio-match triple for [_onReadyForDisplay] after covering ends.
    _audioHoldAssetId = hadTarget;
    _audioHoldFeedIndex = targetIndex;
    _audioHoldEpoch = state.armPoolEpoch;
    state = const PvTransitionGuardState();
    _armedDisplayGate = null;
  }

  /// Audio half of disarm: ends transition suppress.
  /// Bound to poster-hold clear / ready-for-display — not settle-on-target.
  Future<void> releaseTransitionAudio({
    required String reason,
    bool resumePlay = false,
  }) async {
    if (!_transitionAudioHeld) {
      return;
    }
    _transitionAudioHeld = false;
    final playAsset = _audioHoldAssetId;
    final playIndex = _audioHoldFeedIndex;
    _audioHoldAssetId = null;
    _audioHoldFeedIndex = null;
    _audioHoldEpoch = null;
    final playback = ref.read(playbackRepositoryProvider);
    await playback.setTransitionAudioSuppressed(false);
    if (resumePlay &&
        playAsset != null &&
        playIndex == ref.read(mainBrowseFeedIndexProvider)) {
      await ref.read(playbackCoordinatorProvider).onTransitionHandoffResume(
            assetIdentifier: playAsset,
            isStillCurrentPage: () =>
                playIndex == ref.read(mainBrowseFeedIndexProvider),
            permission: SystemPlaybackPermission(
              isForegroundLifecycle:
                  ref.read(playbackCoordinatorProvider).isForegroundLifecycle,
              isCurrentPage: true,
              isL2ReadyVideo: true,
              isSurfaceReady: true,
              transitionBlocksPlayback: false,
              hasHardPlaybackFailure: false,
            ),
            muted: ref.read(sharedMuteProvider),
          );
    }
  }

  /// Full teardown: covering + transition audio.
  Future<void> disarm({
    bool resumePlay = false,
    String reason = 'manual',
    int? settledIdx,
    int? newIdx,
  }) async {
    final hadTarget = state.targetAssetId ?? _audioHoldAssetId;
    final targetIndex = state.targetFeedIndex ?? _audioHoldFeedIndex;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    state = const PvTransitionGuardState();
    _armedDisplayGate = null;
    final playback = ref.read(playbackRepositoryProvider);
    if (_transitionAudioHeld) {
      _transitionAudioHeld = false;
      _audioHoldAssetId = null;
      _audioHoldFeedIndex = null;
      _audioHoldEpoch = null;
      await playback.setTransitionAudioSuppressed(false);
    }
    if (resumePlay &&
        hadTarget != null &&
        targetIndex == ref.read(mainBrowseFeedIndexProvider)) {
      await ref.read(playbackCoordinatorProvider).onTransitionHandoffResume(
            assetIdentifier: hadTarget,
            isStillCurrentPage: () =>
                targetIndex == ref.read(mainBrowseFeedIndexProvider),
            permission: const SystemPlaybackPermission(
              isForegroundLifecycle: true,
              isCurrentPage: true,
              isL2ReadyVideo: true,
              isSurfaceReady: true,
              transitionBlocksPlayback: false,
              hasHardPlaybackFailure: false,
            ),
            muted: ref.read(sharedMuteProvider),
          );
    }
  }

  /// First-frame ready: if still covering, full disarm; if covering already
  /// released (settle-on-target), release transition audio only.
  void _onReadyForDisplay(PlaybackSurfaceReadyForDisplayEvent event) {
    final guard = state;
    if (guard.targetAssetId != null) {
      final generation = guard.displayGeneration;
      final gate = _armedDisplayGate;
      if (generation == null ||
          gate == null ||
          guard.armPoolEpoch == null) {
        return;
      }
      if (event.assetIdentifier != guard.targetAssetId) {
        return;
      }
      if (event.feedIndex != guard.targetFeedIndex) {
        return;
      }
      if (event.clearEpoch != guard.armPoolEpoch) {
        return;
      }
      unawaited(disarm(resumePlay: true, reason: 'ready-for-display'));
      return;
    }

    if (!_transitionAudioHeld ||
        _audioHoldAssetId == null ||
        _audioHoldFeedIndex == null ||
        _audioHoldEpoch == null) {
      return;
    }
    if (event.assetIdentifier != _audioHoldAssetId) {
      return;
    }
    if (event.feedIndex != _audioHoldFeedIndex) {
      return;
    }
    if (event.clearEpoch != _audioHoldEpoch) {
      return;
    }
    unawaited(
      releaseTransitionAudio(reason: 'ready-for-display', resumePlay: true),
    );
  }

  void _armTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 2), () {
      unawaited(disarm(reason: 'timeout'));
    });
  }
}

final pvTransitionGuardProvider =
    NotifierProvider<PvTransitionGuardNotifier, PvTransitionGuardState>(
      PvTransitionGuardNotifier.new,
    );
