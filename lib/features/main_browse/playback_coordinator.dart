import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';

/// Cap 18.3 / ADR-040: sole Dart exit for effective [PlaybackRepository.play]
/// and [PlaybackRepository.pause] after [PlaybackRepository.setPlaybackIntent].
///
/// Cap 18.4: extends [ChangeNotifier] so UI can rebuild on intent /
/// foreground-lifecycle changes without Host runtime observe (18.2).
class PlaybackCoordinator extends ChangeNotifier {
  PlaybackCoordinator({required PlaybackRepository playback})
      : _playback = playback;

  final PlaybackRepository _playback;
  Future<void> _chain = Future<void>.value();

  String? _lastIntentSyncAssetId;
  int? _lastIntentSyncDisplayGeneration;
  bool _userIntentWantsPlay = true;
  bool _isForegroundLifecycle = true;

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

  /// Become-current after Layer 2 [load] (and optionally surface-ready).
  Future<void> onVideoBecomeCurrent({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
    required SystemPlaybackPermission permission,
    required bool muted,
  }) {
    return _enqueue(() async {
      final nav = _isNewNavigationActivation(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
      );
      if (nav && _isForegroundLifecycle) {
        _setUserIntentWantsPlay(true);
      }
      await _syncIntentAndPlayback(
        assetIdentifier: assetIdentifier,
        displayGeneration: displayGeneration,
        displayGate: displayGate,
        startsNewNavigationActivation: nav && _isForegroundLifecycle,
        clearsPendingNavigationActivation: !_isForegroundLifecycle,
        permission: permission,
        muted: muted,
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
      await _playback
          .seek(positionSeconds)
          .timeout(_scrubSeekTimeout);
      return true;
    } on TimeoutException {
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

    final effective = effectiveShouldPlay(
      userIntentWantsPlay: _userIntentWantsPlay,
      permission: permission,
    );

    if (effective) {
      await _playback.setMute(muted);
      if (!stillCurrent()) {
        return;
      }
      await _playback.play();
    } else {
      await _playback.pause();
    }

    if (!stillCurrent()) {
      return;
    }
  }
}
