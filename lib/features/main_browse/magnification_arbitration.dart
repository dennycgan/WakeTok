import 'dart:ui' show Offset;

/// Cap 20.2 / ADR-043 — pure magnification arbitration helpers.
///
/// Product pinch UI lands in 20.3+; these predicates drive PageView lock,
/// left-swipe arming consumers, and force-fit clears.

/// Vertical [PageView] must not scroll while a still is persistently
/// magnified, a transient pinch is in progress, or still two-finger contact
/// is active (ADR-043 D3 + Cap 20.3 Plan A).
bool verticalPageViewScrollLocked({
  required bool isCurrentStillMagnified,
  required bool transientPinchActive,
  bool stillPinchContact = false,
}) {
  return isCurrentStillMagnified || transientPinchActive || stillPinchContact;
}

/// Any rising edge of Live motion PV mount while magnification is active
/// → force fit (ADR-043 D1). Covers persistent still **and** in-progress
/// transient pinch flags. Also covers auto play-once **and** a future
/// explicit replay control (ADR-040 Decision 17) without rewriting the guard.
bool shouldForceFitOnLiveMotionRisingEdge({
  required bool previouslyMounted,
  required bool currentlyMounted,
  required bool hasActiveMagnification,
}) {
  return !previouslyMounted && currentlyMounted && hasActiveMagnification;
}

/// Cap 19 actions half-sheet open rising edge → force fit (ADR-043 D4).
///
/// Clears persistent still magnification **and** in-progress transient pinch.
bool shouldForceFitOnActionsPanelOpen({
  required bool previouslyOpen,
  required bool currentlyOpen,
  required bool hasActiveMagnification,
}) {
  return !previouslyOpen && currentlyOpen && hasActiveMagnification;
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

/// Cap 25 Share dismiss: pointer ids whose down wall-clock is at or before
/// Host [dismissedAtMs] (residuals). Ids with `downAtMs > dismissedAtMs`
/// are post-dismiss gestures and must be kept.
Set<int> pointerIdsToClearAfterNativeShareDismiss({
  required Map<int, int> pointerDownAtMs,
  required int dismissedAtMs,
}) {
  return {
    for (final entry in pointerDownAtMs.entries)
      if (entry.value <= dismissedAtMs) entry.key,
  };
}

/// Cap 25 Bug#2: [forceFit] (ADR-043 D4 same entry) then clear residual
/// pointers by [dismissedAtMs]. Mutates [pointers] / [pointerDownAtMs].
///
/// Returns ids removed. Safe when already clean (`forceFit` no-op + empty
/// clear set).
Set<int> recoverBrowseMagnificationAfterNativeShareDismiss({
  required void Function() forceFit,
  required Map<int, Offset> pointers,
  required Map<int, int> pointerDownAtMs,
  required int dismissedAtMs,
}) {
  forceFit();
  final toClear = pointerIdsToClearAfterNativeShareDismiss(
    pointerDownAtMs: pointerDownAtMs,
    dismissedAtMs: dismissedAtMs,
  );
  for (final id in toClear) {
    pointers.remove(id);
    pointerDownAtMs.remove(id);
  }
  return toClear;
}
