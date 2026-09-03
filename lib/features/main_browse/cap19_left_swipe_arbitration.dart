import 'dart:ui';

/// ADR-040 Decision 2 — early-motion classification (2× not implemented in 19.6).
enum Cap19HorizontalGestureIntent {
  none,
  leftSwipeAppend,
  edgeHold2x,
}

/// Minimum leftward travel to count as left-swipe append on release.
const double kCap19LeftSwipeDistanceThreshold = 72;

/// Early horizontal motion threshold (same class as tap vs vertical swipe).
const double kCap19LeftSwipeEarlyMotionThreshold = 24;

/// Stationary hold window before classifying as 2× edge-hold.
const Duration kCap19EdgeHoldWindow = Duration(milliseconds: 400);

Cap19HorizontalGestureIntent classifyEarlyMotion({
  required Offset delta,
  required Duration pressDuration,
}) {
  if (delta.dx.abs() > delta.dy.abs() &&
      delta.dx < -kCap19LeftSwipeEarlyMotionThreshold) {
    return Cap19HorizontalGestureIntent.leftSwipeAppend;
  }
  if (pressDuration >= kCap19EdgeHoldWindow &&
      delta.distance < kCap19LeftSwipeEarlyMotionThreshold) {
    return Cap19HorizontalGestureIntent.edgeHold2x;
  }
  return Cap19HorizontalGestureIntent.none;
}

bool shouldTriggerLeftSwipeAppend({required Offset totalDelta}) {
  if (totalDelta.dx >= -kCap19LeftSwipeDistanceThreshold) {
    return false;
  }
  return totalDelta.dx.abs() > totalDelta.dy.abs();
}

bool leftSwipeArmingAllowed({
  required bool leftSwipeAddEnabled,
  required bool isCurrentStillMagnified,
  required bool cap19PanelOpen,
  required bool currentAssetActionable,
}) {
  if (!leftSwipeAddEnabled) {
    return false;
  }
  if (isCurrentStillMagnified) {
    return false;
  }
  if (cap19PanelOpen) {
    return false;
  }
  if (!currentAssetActionable) {
    return false;
  }
  return true;
}

bool effectiveLeftSwipeGuideVisible({
  required bool leftSwipeAddEnabled,
  required bool leftSwipeGuideEnabled,
  required bool sessionGuideAlreadyShown,
  required bool browseItemReady,
}) {
  return leftSwipeAddEnabled &&
      leftSwipeGuideEnabled &&
      !sessionGuideAlreadyShown &&
      browseItemReady;
}
