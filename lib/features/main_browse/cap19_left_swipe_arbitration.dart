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
  required bool currentAssetMediaCoverVisible,
  bool transientPinchActive = false,
  bool stillPinchContact = false,
  bool orderControlPanelOpen = false,
}) {
  if (!leftSwipeAddEnabled) {
    return false;
  }
  if (isCurrentStillMagnified) {
    return false;
  }
  // Mid multi-touch / transient pinch must not compete with Cap19 full-width
  // translucent Listener (Cap 20.4 device: L2 pinch vs left-swipe conflict).
  if (transientPinchActive || stillPinchContact) {
    return false;
  }
  if (cap19PanelOpen || orderControlPanelOpen) {
    return false;
  }
  if (!currentAssetActionable) {
    return false;
  }
  // Cap 26.4c / ADR-054: no album mutation while cover is unpainted.
  if (!currentAssetMediaCoverVisible) {
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
