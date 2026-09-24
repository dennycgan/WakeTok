/// Cap 30 first-launch guidance chain — pure step / D6 helpers (ADR-060).
///
/// Durable progress uses [kCap30GuideStepComplete] as the upper clamp.
/// When a future Cap appends a clips step (D8), revisit migration: a stored
/// `3` means “v1 chain finished”, not necessarily “clips tip finished”.

/// Disk value when `<1>`+`<2>` have finished (no further first-launch chain).
const int kCap30GuideStepComplete = 3;

/// `<1>` vertical up/down coach — display duration (independent per step).
const Duration kCap30VerticalHintGuideDuration = Duration(milliseconds: 2000);

/// `<2>` Create Pool tip — display duration (independent per step).
const Duration kCap30CreatePoolTipDuration = Duration(milliseconds: 3500);

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

/// Display duration for [chrome]. Each step owns its own constant — do not
/// collapse to a single shared duration when adding clips / later tips.
Duration cap30GuideChromeDuration(Cap30GuideChromeKind chrome) {
  switch (chrome) {
    case Cap30GuideChromeKind.verticalHint:
      return kCap30VerticalHintGuideDuration;
    case Cap30GuideChromeKind.createPoolTip:
      return kCap30CreatePoolTipDuration;
    case Cap30GuideChromeKind.none:
      return Duration.zero;
  }
}

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
