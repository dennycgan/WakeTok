/// Cap 30 first-launch guidance chain — pure step / D6 helpers (ADR-060).
///
/// Durable progress uses [kCap30GuideStepComplete] as the upper clamp.
/// When a future Cap appends a clips step (D8), revisit migration: a stored
/// `3` means “v1 chain finished”, not necessarily “clips tip finished”.

/// Disk value when `<1>`+`<2>` have finished (no further first-launch chain).
const int kCap30GuideStepComplete = 3;

/// Coach step duration — same as Cap 19 left-swipe tip (Q1).
const Duration kCap30GuideStepDuration = Duration(milliseconds: 2500);

/// Which chrome the orchestrator may show (D8 ordered list; no clips yet).
enum Cap30GuideChromeKind {
  none,
  verticalHint,
  createPoolTip,
}

/// Ordered `<1>` → `<2>` list. Future clips tip appends here (D8); not built.
const List<Cap30GuideChromeKind> kCap30FirstLaunchStepOrder =
    <Cap30GuideChromeKind>[
  Cap30GuideChromeKind.verticalHint,
  Cap30GuideChromeKind.createPoolTip,
];

/// Clamp raw prefs int into `0..kCap30GuideStepComplete`.
///
/// Values above complete → complete (do not replay). Negatives → `0`.
int clampCap30GuideStep(int raw) {
  if (raw < 0) {
    return 0;
  }
  if (raw > kCap30GuideStepComplete) {
    return kCap30GuideStepComplete;
  }
  return raw;
}

/// ADR-060 D6 — narrow gate vs Cap 19 left-swipe tip (pure; Host wiring later).
bool shouldBlockLeftSwipeGuideForCap30({
  required int diskStep,
  required bool chainArmedThisLaunch,
}) {
  final step = clampCap30GuideStep(diskStep);
  if (step == 1 || step == 2) {
    return true;
  }
  if (step == 0 && chainArmedThisLaunch) {
    return true;
  }
  return false;
}
