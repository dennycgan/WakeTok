// Cap 17.3 / ADR-034 Decision 2 — wait chrome by path-class × duration band.
//
// Why features (not domain): presentation-only policy for Main Browse corner
// chrome; no cross-feature reuse or domain business rules.
//
// [isCurrent] is consulted **only** for [WaitChromePathClass.a4L2ReadyEvict]
// inside this helper (a4 peek → none). Paint-layer rules G / B / F1 / E / C/F2
// live in vertical_media_feed.dart (ADR-034 Cap 17.3 Decision 2 extension).

/// Default a4 suppress-below threshold T (17.1 Full a4 buckets 65/108/13;
/// owner D1=A; Cap 17.3 lock T=150 ms). Not a claim that every a4 is &lt;200 ms.
const Duration kDefaultA4SuppressBelow = Duration(milliseconds: 150);

/// ADR-039 source-switch-only Layer-1 visible center-label delay.
///
/// This starts at 150 ms to hide one-frame source remount copy while restoring
/// feedback quickly on a sustained wait. It is intentionally independent from
/// [kDefaultA4SuppressBelow], whose value came from the a4 wait distribution.
const Duration kSourceSwitchLayer1CenterLabelDelay = Duration(
  milliseconds: 150,
);

/// Track A path classes (Cap 17.1). a5/a6 fold into the a4 band policy.
enum WaitChromePathClass {
  /// Layer 1 miss — immediate corner chrome (ADR-031 Q2).
  a1Miss,

  /// Wait-to-playable / networked Layer 2 — immediate spinner (no progress in 17.3).
  a2WaitToPlayable,

  /// L2-ready hit with cover — no wait chrome.
  a3L2ReadyHit,

  /// Host-temp / L2-ready cover eviction revisit (and a5/a6 band fold).
  a4L2ReadyEvict,
}

enum WaitChromeKind { none, cornerSpinnerImmediate, cornerSpinnerAfterBand }

/// Resolves whether Main Browse should show Layer-2 wait corner chrome.
///
/// [a1Miss] / [a2WaitToPlayable]: ignore [isCurrent] and [elapsedInFlight]
/// (and ignore [a4SuppressBelow]). Still a2 suppress-below-T (G) is applied
/// in the feed page paint path — not here — so video a2 stays immediate.
/// [a3L2ReadyHit]: always [WaitChromeKind.none].
/// [a4L2ReadyEvict]: if `!isCurrent` → none; if current and elapsed &lt; T → none;
/// if current and elapsed ≥ T → after-band spinner.
WaitChromeKind resolveWaitChrome({
  required WaitChromePathClass path,
  required Duration elapsedInFlight,
  required Duration a4SuppressBelow,
  required bool isCurrent,
}) {
  switch (path) {
    case WaitChromePathClass.a1Miss:
      // Production L1-miss does not call this function; the a1 branch exists
      // only for unit-test parity with the path-class enum. See the `_loading`
      // early-return in vertical_media_feed.dart (Plan A: leave that path alone).
      return WaitChromeKind.cornerSpinnerImmediate;
    case WaitChromePathClass.a2WaitToPlayable:
      return WaitChromeKind.cornerSpinnerImmediate;
    case WaitChromePathClass.a3L2ReadyHit:
      return WaitChromeKind.none;
    case WaitChromePathClass.a4L2ReadyEvict:
      if (!isCurrent) {
        return WaitChromeKind.none;
      }
      if (elapsedInFlight < a4SuppressBelow) {
        return WaitChromeKind.none;
      }
      return WaitChromeKind.cornerSpinnerAfterBand;
  }
}

/// True when an a4 / still-a2 reveal-timer tick should call [setState].
///
/// Stale ticks after re-arm / leave must no-op when [armedGeneration] no longer
/// matches the page's current in-flight generation (same class of leave-late
/// callback defense as Host finishLoad / Track B).
bool shouldApplyA4ChromeRevealTick({
  required bool isMounted,
  required bool layer2InFlight,
  required int? armedGeneration,
  required int? currentInFlightGeneration,
}) {
  if (!isMounted || !layer2InFlight) {
    return false;
  }
  return currentInFlightGeneration == armedGeneration;
}

/// True when [kind] should paint a corner wait spinner.
bool waitChromeShowsSpinner(WaitChromeKind kind) {
  return kind == WaitChromeKind.cornerSpinnerImmediate ||
      kind == WaitChromeKind.cornerSpinnerAfterBand;
}

/// ADR-039: visible Layer-1 center copy is immediate except on the first
/// current page mounted by an All / Photos / Videos source switch.
///
/// The corner spinner and its semantics remain immediate; this helper controls
/// visible center copy only.
bool shouldShowLayer1CenterLabel({
  required bool showLoadingSpinner,
  required bool sourceSwitchDelayArmed,
  required Duration elapsedSinceArm,
  Duration suppressBelow = kSourceSwitchLayer1CenterLabelDelay,
}) {
  if (!showLoadingSpinner) {
    return false;
  }
  if (!sourceSwitchDelayArmed) {
    return true;
  }
  return elapsedSinceArm >= suppressBelow;
}

/// Cap 17.5b: corner reassure copy after this dwell of Layer-2 wait chrome.
///
/// Owner subjective lock (not a derived constant). Same class of timer as
/// a4 reveal — leave must cancel; ticks are generation-gated.
const Duration kLayer2CornerReassureAfter = Duration(seconds: 3);

/// Cap 17.5b Package B: whether to paint short copy left of the gold spinner.
///
/// Pure incremental: may show with Layer 1 / poster present (corner only).
/// LIVE badge may coexist: chrome stacks LIVE **above** the spinner row so
/// horizontal width stays within Overlay [trailingInset] without soft-degrade
/// hide. ADR-039 removed the separate center Layer2Waiting copy.
///
/// Trigger AND: current ∧ L2 in-flight ∧ wait spinner visible ∧ ¬a4 ∧
/// ¬L1-miss page ∧ ¬fail ∧ elapsed ≥ [kLayer2CornerReassureAfter].
/// Coverless is **not** required. LIVE visibility is **not** a gate.
bool shouldShowLayer2CornerReassure({
  required bool isCurrent,
  required bool layer2InFlight,
  required bool layer2Failed,
  required bool loadingMissPage,
  required WaitChromePathClass path,
  required Duration elapsedInFlight,
  required bool waitSpinnerVisible,
}) {
  if (!isCurrent || !layer2InFlight || layer2Failed) {
    return false;
  }
  if (loadingMissPage) {
    return false;
  }
  if (path == WaitChromePathClass.a4L2ReadyEvict) {
    return false;
  }
  if (!waitSpinnerVisible) {
    return false;
  }
  if (elapsedInFlight < kLayer2CornerReassureAfter) {
    return false;
  }
  return true;
}

/// True when a corner-reassure Timer tick should call [setState].
///
/// Same leave/re-arm defense as [shouldApplyA4ChromeRevealTick].
bool shouldApplyLayer2ReassureTick({
  required bool isMounted,
  required bool layer2InFlight,
  required int? armedGeneration,
  required int? currentInFlightGeneration,
}) {
  if (!isMounted || !layer2InFlight) {
    return false;
  }
  return currentInFlightGeneration == armedGeneration;
}
