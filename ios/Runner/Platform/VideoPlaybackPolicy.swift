import Foundation

/// Foreground item-loop vs ADR-006 D4 plan-end (Cap 14.4d).
///
/// D4 (“Plan end: Stop at last item; keep position; no loop”) binds
/// native **background plan-advance**, not Manual Browse `AVPlayerItem`
/// end. Unconditional loop on every item would loop a one-item lock-screen
/// plan and violate D4 — that branch must stay `stopKeepPosition`.
enum VideoItemEndAction: Equatable {
  /// Foreground page-driven current video: seek 0 and play.
  case loopSeekZeroAndPlay
  /// ADR-006 D4: plan finished under background advance — do not loop.
  case stopKeepPosition
  /// Warming, stale observer, or not the current item.
  case ignore
}

/// Re-enter a still-pooled player (ADR-023 D6 playhead sharing).
enum VideoReenterAction: Equatable {
  case seekZeroAndPlay
  case playOnly
  case prepareNew
}

enum VideoPlaybackPolicy {
  /// Item-end policy. [isBackgroundPlanAdvance] is checked first so D4
  /// wins if both mode flags were ever true together.
  static func actionOnItemEnd(
    isForegroundPageDriven: Bool,
    isBackgroundPlanAdvance: Bool,
    isActiveCurrent: Bool,
    observedItemIsCurrentItem: Bool
  ) -> VideoItemEndAction {
    if !observedItemIsCurrentItem {
      return .ignore
    }
    // ADR-006 D4: native plan-advance at last item — stop, keep position,
    // do not loop the plan (including a one-item Browse-shaped plan).
    if isBackgroundPlanAdvance {
      return .stopKeepPosition
    }
    if isForegroundPageDriven, isActiveCurrent {
      return .loopSeekZeroAndPlay
    }
    return .ignore
  }

  static func actionOnBecomeCurrent(
    playerExists: Bool,
    itemAtEnd: Bool
  ) -> VideoReenterAction {
    if !playerExists {
      return .prepareNew
    }
    if itemAtEnd {
      return .seekZeroAndPlay
    }
    return .playOnly
  }
}
