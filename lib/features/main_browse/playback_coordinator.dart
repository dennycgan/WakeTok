import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/playback_activation_source.dart';

/// Cap 18.3 / ADR-040: sole Dart exit for effective [PlaybackRepository.play]
/// and [PlaybackRepository.pause] after [PlaybackRepository.setPlaybackIntent].
///
/// Cap 18.4: extends [ChangeNotifier] so UI can rebuild on intent /
/// foreground-lifecycle changes without Host runtime observe (18.2).
///
/// Cap 28.4 / ADR-058: [PlaybackActivationSource.settingsResume] preserves
/// playhead + pause intent; never inferred from generation deltas. When the
/// 1+1 player was released while Settings was open, resume seeks to the
/// leave-time latch (runtime snapshot) — ADR-023 D6 only covers a still-
/// pooled same-asset player, not durable playhead after eviction.
class PlaybackCoordinator extends ChangeNotifier {
  PlaybackCoordinator({required PlaybackRepository playback})
      : _playback = playback {
    _runtimeSub = _playback.runtimeEvents.listen(_onRuntimeEvent);
  }

  final PlaybackRepository _playback;
  Future<void> _chain = Future<void>.value();
  StreamSubscription<PlaybackRuntimeEvent>? _runtimeSub;

  String? _lastIntentSyncAssetId;
  int? _lastIntentSyncDisplayGeneration;
  bool _userIntentWantsPlay = true;
  bool _isForegroundLifecycle = true;

  /// Last Host runtime tick (scrubber / observe). Used to latch Settings leave.
  String? _lastRuntimeAssetId;
  double? _lastRuntimePositionSeconds;

  /// Snapshotted on Browse→Settings; consumed on [settingsResume] become-current.
  String? _settingsLeaveAssetId;
  double? _settingsLeavePlayheadSeconds;

  bool get userIntentWantsPlay => _userIntentWantsPlay;

  bool get isForegroundLifecycle => _isForegroundLifecycle;

  /// When [onLeaveForeground] ran before L2 surface-ready, resume epoch sync
  /// may miss; call before [onVideoBecomeCurrent] if binding is [resumed].
  void reconcileAppForegroundResumed() {
    _setForegroundLifecycle(true);
  }

  String? get lastIntentSyncAssetId => _lastIntentSyncAssetId;

  @visibleForTesting
  int? get lastIntentSyncDisplayGeneration =>
      _lastIntentSyncDisplayGeneration;

  @visibleForTesting
  double? get debugSettingsLeavePlayheadSeconds =>
      _settingsLeavePlayheadSeconds;

  @visibleForTesting
  String? get debugSettingsLeaveAssetId => _settingsLeaveAssetId;

  @override
  void dispose() {
    unawaited(_runtimeSub?.cancel());
    _runtimeSub = null;
    super.dispose();
  }

  void _onRuntimeEvent(PlaybackRuntimeEvent event) {
    final id = event.currentItemIdentifier;
    if (id.isEmpty) {
      return;
    }
    _lastRuntimeAssetId = id;
    final sec = event.playbackPositionSeconds;
    if (sec.isFinite && sec >= 0) {
      _lastRuntimePositionSeconds = sec;
    }
  }

  /// Cap 28.4: Browse→Settings — latch playhead for possible player re-prepare.
  void onSettingsLeave({required String? currentAssetId}) {
    if (currentAssetId == null || currentAssetId.isEmpty) {
      _settingsLeaveAssetId = null;
      _settingsLeavePlayheadSeconds = null;
      return;
    }
    _settingsLeaveAssetId = currentAssetId;
    if (_lastRuntimeAssetId == currentAssetId &&
        _lastRuntimePositionSeconds != null) {
      _settingsLeavePlayheadSeconds = _lastRuntimePositionSeconds;
    } else {
      // No trusted tick for this asset — Host may still hold playhead if pooled.
      _settingsLeavePlayheadSeconds = null;
    }
  }

  /// Test seam: arm leave playhead without runtime events (player-released case).
  @visibleForTesting
  void debugArmSettingsLeavePlayhead({
    required String assetId,
    required double positionSeconds,
  }) {
    _settingsLeaveAssetId = assetId;
    _settingsLeavePlayheadSeconds = positionSeconds;
  }

  void _setUserIntentWantsPlay(bool value) {
    if (_userIntentWantsPlay == value) {
      return;
    }
    _userIntentWantsPlay = value;
    notifyListeners();
  }

  void _setForegroundLifecycle(bool value) {
    if (_isForegroundLifecycle == value) {
      return;
    }
    _isForegroundLifecycle = value;
    notifyListeners();
  }

  bool _isNewNavigationActivation({
    required String assetIdentifier,
    required int displayGeneration,
  }) {
    return _lastIntentSyncAssetId != assetIdentifier ||
        _lastIntentSyncDisplayGeneration != displayGeneration;
  }

  void _markIntentSynced({
    required String assetIdentifier,
    required int displayGeneration,
  }) {
    _lastIntentSyncAssetId = assetIdentifier;
    _lastIntentSyncDisplayGeneration = displayGeneration;
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.catchError((_) {});
    return next;
  }

  bool _gateStillCurrent(FeedMediaRequestGate? gate, int generation) {
    return gate == null || gate.isCurrent(generation);
  }

  double? _takeSettingsResumePlayhead(String assetIdentifier) {
    if (_settingsLeaveAssetId != assetIdentifier) {
      return null;
    }
    final seconds = _settingsLeavePlayheadSeconds;
    _settingsLeaveAssetId = null;
    _settingsLeavePlayheadSeconds = null;
    return seconds;
  }

  void _clearSettingsLeaveLatch() {
    _settingsLeaveAssetId = null;
    _settingsLeavePlayheadSeconds = null;
  }

  /// Become-current after Layer 2 [load] (and optionally surface-ready).
  ///
  /// [browseCoverOpen]: Cap 21.4b Build cover — suppress the whole navigation
  /// activation (intent reset **and** [startsNewNavigationActivation]) so an
  /// iCloud L1→L2 completion under the cover cannot arm Host pending / play.
  /// Still syncs + pauses so [_markIntentSynced] runs (pop must not look like
  /// a fresh nav activation).
  ///
  /// [activationSource]: Cap 28.4 explicit source. [settingsResume] never
  /// seek0 / force wantsPlay; may seek to leave-time latch after re-prepare.
  Future<void> onVideoBecomeCurrent({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
    required SystemPlaybackPermission permission,
    required bool muted,
    bool browseCoverOpen = false,
    PlaybackActivationSource activationSource =
        PlaybackActivationSource.navigation,
  }) {
    return _enqueue(() async {
      final settingsResume =
          activationSource == PlaybackActivationSource.settingsResume;
      final nav = !settingsResume &&
          _isNewNavigationActivation(
            assetIdentifier: assetIdentifier,
            displayGeneration: displayGeneration,
          );
      final allowNavActivation =
          nav && _isForegroundLifecycle && !browseCoverOpen;
      if (allowNavActivation) {
        _setUserIntentWantsPlay(true);
        _clearSettingsLeaveLatch();
      }
      final resumePlayhead =
          settingsResume ? _takeSettingsResumePlayhead(assetIdentifier) : null;
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
        displayGate: displayGate,
        startsNewNavigationActivation: allowNavActivation,
        clearsPendingNavigationActivation: !_isForegroundLifecycle,
        permission: permission,
        muted: muted,
        resumePlayheadSeconds: resumePlayhead,
      );
    });
  }

  /// Lifecycle leave (inactive / paused / hidden / background).
  ///
  /// Mechanical pause only — preserves [userIntentWantsPlay] so a system
  /// interrupt can auto-resume on foreground; user tap pause stays paused.
  Future<void> onLeaveForeground({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
  }) {
    return _enqueue(() async {
      _setForegroundLifecycle(false);
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
        displayGate: displayGate,
        startsNewNavigationActivation: false,
        clearsPendingNavigationActivation: true,
        permission: SystemPlaybackPermission.denied(),
        muted: false,
      );
    });
  }

  /// Foreground resume after lifecycle leave: restore permission and re-apply
  /// preserved intent. Never a navigation activation; never mutates intent.
  Future<void> onForegroundResumeSync({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
    required SystemPlaybackPermission permission,
    required bool muted,
  }) {
    // Synchronous so callers building permission after this see foreground=true.
    _setForegroundLifecycle(true);
    return _enqueue(() async {
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
        displayGate: displayGate,
        startsNewNavigationActivation: false,
        clearsPendingNavigationActivation: false,
        permission: permission,
        muted: muted,
      );
    });
  }

  /// Cap 18.4: media-area tap toggles user intent (never a navigation
  /// activation; never clears pending navigation activation).
  Future<void> onUserTapTogglePlay({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
    required SystemPlaybackPermission permission,
    required bool muted,
  }) {
    return _enqueue(() async {
      _setUserIntentWantsPlay(!_userIntentWantsPlay);
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
        displayGate: displayGate,
        startsNewNavigationActivation: false,
        clearsPendingNavigationActivation: false,
        permission: permission,
        muted: muted,
      );
    });
  }

  /// Cap 18.5 scrub release — await seek with wall-clock cap so [_enqueue]
  /// cannot deadlock when Host zero-tolerance seek never callbacks.
  static const Duration _scrubSeekTimeout = Duration(milliseconds: 900);

  Future<bool> _attemptScrubSeek(double positionSeconds) async {
    try {
      await _playback.seek(positionSeconds).timeout(_scrubSeekTimeout);
      return true;
    } on TimeoutException {
      debugPrint(
        'WT18.5.scrubPreview seekDiag dartTimeout '
        'requestSec=${positionSeconds.toStringAsFixed(2)}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cap 18.5: single seek on release, then restore effective play/pause.
  /// Cap 19.2b: no mechanical pause on drag begin — main picture follows
  /// [effectiveShouldPlay] while dragging.
  Future<void> onUserScrubComplete({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
    required double positionSeconds,
    required SystemPlaybackPermission permission,
    required bool muted,
  }) {
    return _enqueue(() async {
      final capturedGen = displayGeneration;

      bool stillCurrent() =>
          _gateStillCurrent(displayGate, capturedGen);

      if (!stillCurrent()) {
        return;
      }

      // Drop stale one-shot nav activation before play — otherwise Host
      // play() consumes pending and seekZeroAndPlay overwrites scrub seek.
      await _playback.setPlaybackIntent(
        PlaybackIntent(
          assetIdentifier: assetIdentifier,
          wantsPlay: _userIntentWantsPlay,
          startsNewNavigationActivation: false,
          clearsPendingNavigationActivation: true,
        ),
      );
      if (!stillCurrent()) {
        return;
      }

      var seekApplied = await _attemptScrubSeek(positionSeconds);
      if (!seekApplied) {
        seekApplied = await _attemptScrubSeek(positionSeconds);
      }
      if (!stillCurrent()) {
        return;
      }
      if (!seekApplied) {
        // Best-effort resume from current playhead when Host rejected both seeks.
      }

      _markIntentSynced(
        assetIdentifier: assetIdentifier,
        displayGeneration: capturedGen,
      );

      final effective = effectiveShouldPlay(
        userIntentWantsPlay: _userIntentWantsPlay,
        permission: permission,
      );

      if (effective) {
        await _playback.setMute(muted);
        if (!stillCurrent()) {
          return;
        }
        await _playback.playFromCurrentPosition();
      } else {
        await _playback.pause();
      }
    });
  }

  /// Swipe-away / source switch: mechanical pause without intent mutation.
  Future<void> onLeaveCurrent() {
    return _enqueue(() async {
      await _playback.pause();
    });
  }

  /// Cap 21.4b: full-screen Browse cover (Build a Pool) opened.
  ///
  /// Sets user intent to paused + Host pause so the center play affordance is
  /// already painted under the cover and visible the instant the route pops
  /// (no empty frame, no double-tap). Distinct from [onLeaveForeground]
  /// (preserves intent for auto-resume) and [onLeaveCurrent] (mechanical).
  /// Pair with [onVideoBecomeCurrent] `browseCoverOpen: true` so a later
  /// L1→L2 become-current under the cover cannot re-arm nav activation.
  Future<void> onBrowseCoverOpened() {
    return _enqueue(() async {
      _setUserIntentWantsPlay(false);
      await _playback.pause();
    });
  }

  /// PvTransitionGuard handoff resume — preserves user intent, no nav activation.
  Future<void> onTransitionHandoffResume({
    required String assetIdentifier,
    required bool Function() isStillCurrentPage,
    required SystemPlaybackPermission permission,
    required bool muted,
  }) {
    return _enqueue(() async {
      if (!isStillCurrentPage()) {
        return;
      }
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: _lastIntentSyncDisplayGeneration ?? -1,
        displayGate: null,
        startsNewNavigationActivation: false,
        clearsPendingNavigationActivation: false,
        permission: permission,
        muted: muted,
        staleGuard: isStillCurrentPage,
      );
    });
  }

  Future<void> _syncIntentAndPlayback({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate? displayGate,
    required bool startsNewNavigationActivation,
    required bool clearsPendingNavigationActivation,
    required SystemPlaybackPermission permission,
    required bool muted,
    bool Function()? staleGuard,
    double? resumePlayheadSeconds,
  }) async {
    final capturedGen = displayGeneration;

    bool stillCurrent() {
      if (staleGuard != null && !staleGuard()) {
        return false;
      }
      return _gateStillCurrent(displayGate, capturedGen);
    }

    if (!stillCurrent()) {
      return;
    }

    final wantsPlay = _userIntentWantsPlay;
    await _playback.setPlaybackIntent(
      PlaybackIntent(
        assetIdentifier: assetIdentifier,
        wantsPlay: wantsPlay,
        startsNewNavigationActivation: startsNewNavigationActivation,
        clearsPendingNavigationActivation: clearsPendingNavigationActivation,
      ),
    );

    if (!stillCurrent()) {
      return;
    }

    _markIntentSynced(
      assetIdentifier: assetIdentifier,
      displayGeneration: capturedGen,
    );

    // Cap 28.4: after player re-prepare (seek0 default), restore leave playhead
    // before play/pause. Prefer playFromCurrentPosition after seek so Host
    // re-enter seek-zero policy is not re-armed.
    final resumeSec = resumePlayheadSeconds;
    if (resumeSec != null && resumeSec.isFinite && resumeSec > 0) {
      await _attemptScrubSeek(resumeSec);
      if (!stillCurrent()) {
        return;
      }
    }

    final effective = effectiveShouldPlay(
      userIntentWantsPlay: _userIntentWantsPlay,
      permission: permission,
    );

    if (effective) {
      await _playback.setMute(muted);
      if (!stillCurrent()) {
        return;
      }
      if (resumeSec != null && resumeSec.isFinite && resumeSec > 0) {
        await _playback.playFromCurrentPosition();
      } else {
        await _playback.play();
      }
    } else {
      await _playback.pause();
    }

    if (!stillCurrent()) {
      return;
    }
  }
}
