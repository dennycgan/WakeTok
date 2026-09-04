/// Cap 20.2 / ADR-043 — pure magnification arbitration helpers.
///
/// Product pinch UI lands in 20.3+; these predicates drive PageView lock,
/// left-swipe arming consumers, and force-fit clears.

/// Vertical [PageView] must not scroll while a still is persistently
/// magnified, a video pinch is in progress, or still two-finger contact
/// is active (ADR-043 D3 + Cap 20.3 Plan A).
bool verticalPageViewScrollLocked({
  required bool isCurrentStillMagnified,
  required bool videoPinchActive,
  bool stillPinchContact = false,
}) {
  return isCurrentStillMagnified || videoPinchActive || stillPinchContact;
}

/// Any rising edge of Live motion PV mount while magnified → force fit
/// (ADR-043 D1). Covers auto play-once **and** a future explicit replay
/// control (ADR-040 Decision 17) without rewriting the guard.
bool shouldForceFitOnLiveMotionRisingEdge({
  required bool previouslyMounted,
  required bool currentlyMounted,
  required bool isStillMagnified,
}) {
  return !previouslyMounted && currentlyMounted && isStillMagnified;
}

/// Cap 19 actions half-sheet open rising edge → force fit (ADR-043 D4).
bool shouldForceFitOnActionsPanelOpen({
  required bool previouslyOpen,
  required bool currentlyOpen,
  required bool isStillMagnified,
}) {
  return !previouslyOpen && currentlyOpen && isStillMagnified;
}

/// Leaving the current feed item (or Browse) clears magnification state.
bool shouldClearMagnificationOnLeaveCurrent({
  required bool wasCurrentOrBrowseActive,
  required bool isCurrentOrBrowseActive,
  required bool hasActiveMagnification,
}) {
  return wasCurrentOrBrowseActive &&
      !isCurrentOrBrowseActive &&
      hasActiveMagnification;
}
