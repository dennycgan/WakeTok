import 'dart:ui' show Offset;

import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';

/// Cap 26.2 / ADR-052 Decision 5 — named hold (align Cap 19 edge-hold window).
const Duration kLiveLongPressHoldDuration = kCap19EdgeHoldWindow;

/// Cap 26.2 / ADR-052 Decision 5 — cancel slop (align Cap 19 early-motion).
const double kLiveLongPressMaxSlopPx = kCap19LeftSwipeEarlyMotionThreshold;

/// Pure long-press classification (U-26.2-1).
enum LiveLongPressPhase {
  tracking,
  cancelled,
  fire,
}

/// Classifies a press that started at the origin and has lasted [pressDuration]
/// with total translation [delta] from the down position.
LiveLongPressPhase classifyLiveLongPress({
  required Offset delta,
  required Duration pressDuration,
}) {
  if (delta.distance > kLiveLongPressMaxSlopPx) {
    return LiveLongPressPhase.cancelled;
  }
  if (pressDuration >= kLiveLongPressHoldDuration) {
    return LiveLongPressPhase.fire;
  }
  return LiveLongPressPhase.tracking;
}

/// Whether Cap 26 may **fire** a new long-press replay (U-26.2-2 / Cap 26.5a).
///
/// Does not answer “keep Listener mounted after fire” — see
/// [shouldMountLiveLongPressListener].
bool shouldArmLiveLongPress({
  required bool isCurrent,
  required bool isLiveStill,
  required bool liveMotionMounted,
  required bool livePreparing,
  required bool liveSilentReplayInFlight,
  required bool isCurrentStillMagnified,
  required bool transientPinchActive,
  required bool stillPinchContact,
  bool cap19PanelOpen = false,
  bool cap24MorePanelOpen = false,
}) {
  if (!isCurrent || !isLiveStill) {
    return false;
  }
  if (liveMotionMounted || livePreparing || liveSilentReplayInFlight) {
    return false;
  }
  if (isCurrentStillMagnified || transientPinchActive || stillPinchContact) {
    return false;
  }
  if (cap19PanelOpen || cap24MorePanelOpen) {
    return false;
  }
  return true;
}

/// Whether the Cap 26 [Listener] must stay mounted (Cap 26.5a hold-through).
///
/// [mayFire] = [shouldArmLiveLongPress]. After fire, pass
/// [holdingAfterFire] true so `liveMotionMounted` / Path S in-flight does
/// **not** tear the Listener before pointer up. Panels / leave-current force
/// `false` so [Cap26LiveLongPressGesture] can deliver release-stop via
/// enabled→false.
bool shouldMountLiveLongPressListener({
  required bool mayFire,
  required bool holdingAfterFire,
  required bool isCurrent,
  bool cap19PanelOpen = false,
  bool cap24MorePanelOpen = false,
}) {
  if (!isCurrent || cap19PanelOpen || cap24MorePanelOpen) {
    return false;
  }
  return mayFire || holdingAfterFire;
}
