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

enum WaitChromeKind {
  none,
  cornerSpinnerImmediate,
  cornerSpinnerAfterBand,
}

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

/// Cap 17.4: coverless wait **label** shares the spinner door.
///
/// Never trigger label from coverless/in-flight alone — callers must pass the
/// same [showWaitSpinner] already used for corner chrome (incl. still a2 G,
/// video a2 immediate, a4 band, and a4+`_loading` B miss suppress).
bool coverlessWaitShowsLabel({required bool showWaitSpinner}) {
  return showWaitSpinner;
}

/// True when the page has no displayable still/poster (debt 400 band).
///
/// Live prepare (`_livePreparing`) is out of Cap 17.4 scope — callers must
/// not treat Live-only chrome as coverless Layer-2 waiting.
bool isCoverlessFeedPresentation({
  required bool loading,
  required bool hasDisplayableCover,
}) {
  if (loading) {
    return true;
  }
  return !hasDisplayableCover;
}
