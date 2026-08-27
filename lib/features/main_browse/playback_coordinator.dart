import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';

/// Cap 18.3 / ADR-040: sole Dart exit for effective [PlaybackRepository.play]
/// and [PlaybackRepository.pause] after [PlaybackRepository.setPlaybackIntent].
class PlaybackCoordinator {
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

  @visibleForTesting
  String? get lastIntentSyncAssetId => _lastIntentSyncAssetId;

  @visibleForTesting
  int? get lastIntentSyncDisplayGeneration =>
      _lastIntentSyncDisplayGeneration;

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
        _userIntentWantsPlay = true;
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

  /// Lifecycle leave (inactive / paused / background).
  Future<void> onLeaveForeground({
    required String assetIdentifier,
    required int displayGeneration,
    required FeedMediaRequestGate displayGate,
  }) {
    return _enqueue(() async {
      _userIntentWantsPlay = false;
      _isForegroundLifecycle = false;
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

  /// Foreground resume — restores permission only; does not restore intent.
  void onForegroundResume() {
    _isForegroundLifecycle = true;
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
