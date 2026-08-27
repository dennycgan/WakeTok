/// Cap 18.3 dual-signal playback intent (ADR-040).
library;

class PlaybackIntent {
  const PlaybackIntent({
    required this.assetIdentifier,
    required this.wantsPlay,
    required this.startsNewNavigationActivation,
    required this.clearsPendingNavigationActivation,
  });

  final String assetIdentifier;
  final bool wantsPlay;
  final bool startsNewNavigationActivation;
  final bool clearsPendingNavigationActivation;

  PlaybackIntent copyWith({
    String? assetIdentifier,
    bool? wantsPlay,
    bool? startsNewNavigationActivation,
    bool? clearsPendingNavigationActivation,
  }) {
    return PlaybackIntent(
      assetIdentifier: assetIdentifier ?? this.assetIdentifier,
      wantsPlay: wantsPlay ?? this.wantsPlay,
      startsNewNavigationActivation:
          startsNewNavigationActivation ?? this.startsNewNavigationActivation,
      clearsPendingNavigationActivation: clearsPendingNavigationActivation ??
          this.clearsPendingNavigationActivation,
    );
  }
}

/// Inputs for [systemPermissionAllowsPlay] (ADR-040 Decision 3).
class SystemPlaybackPermission {
  const SystemPlaybackPermission({
    required this.isForegroundLifecycle,
    required this.isCurrentPage,
    required this.isL2ReadyVideo,
    required this.isSurfaceReady,
    required this.transitionBlocksPlayback,
    required this.hasHardPlaybackFailure,
  });

  final bool isForegroundLifecycle;
  final bool isCurrentPage;
  final bool isL2ReadyVideo;
  final bool isSurfaceReady;
  final bool transitionBlocksPlayback;
  final bool hasHardPlaybackFailure;

  /// Lifecycle left / not current — permission denied without mutating intent.
  factory SystemPlaybackPermission.denied() {
    return const SystemPlaybackPermission(
      isForegroundLifecycle: false,
      isCurrentPage: false,
      isL2ReadyVideo: false,
      isSurfaceReady: false,
      transitionBlocksPlayback: true,
      hasHardPlaybackFailure: false,
    );
  }
}

/// Pure predicate — unit-tested independently from coordinator wiring.
bool systemPermissionAllowsPlay(SystemPlaybackPermission permission) {
  return permission.isForegroundLifecycle &&
      permission.isCurrentPage &&
      permission.isL2ReadyVideo &&
      permission.isSurfaceReady &&
      !permission.transitionBlocksPlayback &&
      !permission.hasHardPlaybackFailure;
}

bool effectiveShouldPlay({
  required bool userIntentWantsPlay,
  required SystemPlaybackPermission permission,
}) {
  return userIntentWantsPlay && systemPermissionAllowsPlay(permission);
}
