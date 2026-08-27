import Foundation

/// Cap 18.3 / ADR-040: persistent user intent mirror bound to clear epoch.
struct PlaybackIntentMirror: Equatable {
  var assetIdentifier: String
  var wantsPlay: Bool
  var clearEpochAtArm: UInt64
}

/// One-shot navigation activation armed by Dart; consumed on become-current policy.
struct PendingNavigationActivation: Equatable {
  var assetIdentifier: String
  var clearEpochAtArm: UInt64
}

/// Host-side intent mirror + pending activation (ADR-040 Decision 7–8).
struct PlaybackIntentHostState: Equatable {
  var mirror: PlaybackIntentMirror?
  var pendingNavigationActivation: PendingNavigationActivation?
}

/// Pure reducer shared by Host and unit tests (ADR-040 Decision 8 matcher).
enum PlaybackIntentStateReducer {
  static func matchesIdentityAndEpoch(
    assetIdentifier: String,
    clearEpochAtArm: UInt64,
    currentAssetIdentifier: String?,
    clearEpoch: UInt64
  ) -> Bool {
    currentAssetIdentifier == assetIdentifier && clearEpochAtArm == clearEpoch
  }

  static func applyIntent(
    state: PlaybackIntentHostState,
    incoming: PlaybackIntentDto,
    currentAssetIdentifier: String?,
    clearEpoch: UInt64
  ) -> PlaybackIntentHostState {
    var next = state
    next.mirror = PlaybackIntentMirror(
      assetIdentifier: incoming.assetIdentifier,
      wantsPlay: incoming.wantsPlay,
      clearEpochAtArm: clearEpoch
    )
    if incoming.startsNewNavigationActivation {
      next.pendingNavigationActivation = PendingNavigationActivation(
        assetIdentifier: incoming.assetIdentifier,
        clearEpochAtArm: clearEpoch
      )
    }
    if incoming.clearsPendingNavigationActivation {
      if let pending = next.pendingNavigationActivation,
        pending.assetIdentifier == incoming.assetIdentifier,
        matchesIdentityAndEpoch(
          assetIdentifier: pending.assetIdentifier,
          clearEpochAtArm: pending.clearEpochAtArm,
          currentAssetIdentifier: currentAssetIdentifier,
          clearEpoch: clearEpoch
        )
      {
        next.pendingNavigationActivation = nil
      }
    }
    return next
  }

  static func trustedWantsPlay(
    state: PlaybackIntentHostState,
    currentAssetIdentifier: String?,
    clearEpoch: UInt64
  ) -> Bool {
    guard let mirror = state.mirror,
      matchesIdentityAndEpoch(
        assetIdentifier: mirror.assetIdentifier,
        clearEpochAtArm: mirror.clearEpochAtArm,
        currentAssetIdentifier: currentAssetIdentifier,
        clearEpoch: clearEpoch
      )
    else {
      return true
    }
    return mirror.wantsPlay
  }

  /// Returns whether a validated pending navigation activation is present.
  /// When [consumePendingActivation] is true, the caller must drop pending after use.
  static func validatedPendingNavigationActivation(
    state: PlaybackIntentHostState,
    currentAssetIdentifier: String?,
    clearEpoch: UInt64
  ) -> PendingNavigationActivation? {
    guard let pending = state.pendingNavigationActivation,
      matchesIdentityAndEpoch(
        assetIdentifier: pending.assetIdentifier,
        clearEpochAtArm: pending.clearEpochAtArm,
        currentAssetIdentifier: currentAssetIdentifier,
        clearEpoch: clearEpoch
      )
    else {
      return nil
    }
    return pending
  }

  static func clearIntentStateOnPoolClear() -> PlaybackIntentHostState {
    PlaybackIntentHostState(mirror: nil, pendingNavigationActivation: nil)
  }
}
