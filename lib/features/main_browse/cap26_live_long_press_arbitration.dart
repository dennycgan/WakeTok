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

/// Whether the Cap 26 long-press Listener may arm / fire (U-26.2-2).
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
